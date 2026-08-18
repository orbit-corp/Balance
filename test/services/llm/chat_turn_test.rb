require "test_helper"

class Llm::ChatTurnTest < ActiveSupport::TestCase
  FakeToolCall = Struct.new(:id, :name)

  class FakeAgent
    attr_reader :completions

    def initialize(chat, contents)
      @chat = chat
      @contents = contents
      @completions = 0
    end

    def before_tool_call(&block); end

    def after_tool_result(&block); end

    def complete
      @completions += 1
      @chat.llm_messages.create!(role: "assistant", content: @contents.shift)
    end
  end

  class ContextOverflowAgent
    attr_reader :completions

    def initialize(chat, fail_forever: false)
      @chat = chat
      @fail_forever = fail_forever
      @completions = 0
    end

    def before_tool_call(&block); end

    def after_tool_result(&block); end

    def complete
      @completions += 1
      if @fail_forever || @completions == 1
        raise RubyLLM::ContextLengthExceededError.new(nil, "Context length exceeded")
      end

      @chat.llm_messages.create!(role: "assistant", content: "Here you go.")
    end
  end

  class ToolLoopAgent
    attr_reader :completions

    def initialize(chat, tool_calls)
      @chat = chat
      @tool_calls = tool_calls
      @before_tool_call = nil
      @completions = 0
    end

    def before_tool_call(&block)
      @before_tool_call = block
    end

    def after_tool_result(&block); end

    def complete
      @completions += 1
      @tool_calls.times do |number|
        @before_tool_call.call(FakeToolCall.new("tool_call_#{number}", "list_journal_entries"))
      end
      @chat.llm_messages.create!(role: "assistant", content: "Here you go.")
    end
  end

  class ReversalToolAgent
    attr_reader :completions

    def initialize(chat, repeated_question)
      @chat = chat
      @repeated_question = repeated_question
      @before_tool_call = nil
      @completions = 0
    end

    def before_tool_call(&block)
      @before_tool_call = block
    end

    def after_tool_result(&block); end

    def complete
      @completions += 1
      @before_tool_call&.call(FakeToolCall.new("tool_call_1", "propose_reversal"))
      @chat.llm_messages.create!(role: "assistant", content: @repeated_question)
    end
  end

  setup do
    @workspace = workspaces(:ada_store)
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Test model"),
      title: "Test chat"
    )
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :other_expense)
  end

  def build_fat_turn(number)
    @chat.llm_messages.create!(role: "user", content: "user #{number}")
    @chat.llm_messages.create!(role: "tool", content: "x" * 1_000)
  end

  test "finish_tool_call feeds an error result back to the model instead of raising" do
    turn = Llm::ChatTurn.new(chat: @chat)
    turn.send(:start_tool_call, FakeToolCall.new("tool_call_1", "propose_entry"))

    result = turn.send(:finish_tool_call, { error: "Ask for the amount before proposing an entry." })

    assert_equal "Ask for the amount before proposing an entry.", result[:error]
    assert_nil turn.instance_variable_get(:@current_tool_call)
    refute @chat.llm_messages.exists?(role: "assistant", content: "Ask for the amount before proposing an entry.")
  end

  test "retries a silent completion once and writes a fallback when it stays silent" do
    agent = FakeAgent.new(@chat, [ "", "" ])

    Llm::ChatTurn.new(chat: @chat, agent: agent).call

    assert_equal 2, agent.completions
    assert_equal [ "I wasn't able to respond. Could you rephrase that?" ], @chat.visible_messages.pluck(:content)
  end

  test "retries a silent completion and keeps a real reply when the retry responds" do
    agent = FakeAgent.new(@chat, [ "", "Here you go." ])

    Llm::ChatTurn.new(chat: @chat, agent: agent).call

    assert_equal 2, agent.completions
    assert_equal [ "Here you go." ], @chat.visible_messages.pluck(:content)
  end

  test "remove_empty_assistant_messages destroys empty messages without tool calls and keeps those with tool calls" do
    bare = @chat.llm_messages.create!(role: "assistant", content: "")
    with_tool = @chat.llm_messages.create!(role: "assistant", content: "")
    with_tool.llm_tool_calls.create!(tool_call_id: "tool_call_2", name: "propose_entry", arguments: {})
    keeps = @chat.llm_messages.create!(role: "user", content: "")

    Llm::ChatBroadcaster.new(@chat).remove_empty_assistant_messages

    refute Llm::Message.exists?(bare.id), "empty assistant message without tool calls should be destroyed"
    assert Llm::Message.exists?(with_tool.id), "empty assistant message with tool calls should be kept"
    assert Llm::Message.exists?(keeps.id), "user messages should be untouched"
  end

  test "compacts and retries once after a context length error" do
    agent = ContextOverflowAgent.new(@chat)
    compactor = Minitest::Mock.new
    compactor.expect(:call, true)

    Llm::ChatTurn.new(chat: @chat, agent: agent, compactor: compactor).call
    compactor.verify

    assert_equal 2, agent.completions
    assert_equal [ "Here you go." ], @chat.visible_messages.pluck(:content)
  end

  test "reports a generic failure when compaction cannot help the overflow" do
    agent = ContextOverflowAgent.new(@chat, fail_forever: true)
    compactor = Object.new
    compactor.define_singleton_method(:call) { false }

    Llm::ChatTurn.new(chat: @chat, agent: agent, compactor: compactor).call

    assert_equal 1, agent.completions
    assert_equal [ "The accounting assistant is temporarily unavailable. Please try again." ],
      @chat.visible_messages.pluck(:content)
  end

  test "reports an honest retry hint when the turn fails unexpectedly" do
    agent = Object.new
    agent.define_singleton_method(:before_tool_call) { |&_block| }
    agent.define_singleton_method(:after_tool_result) { |&_block| }
    agent.define_singleton_method(:complete) { |&_block| raise "boom" }

    Llm::ChatTurn.new(chat: @chat, agent: agent).call

    assert_equal [ "I hit a problem while answering. Please try again." ],
      @chat.visible_messages.pluck(:content)
  end

  test "start_tool_call raises ToolCallLimitExceeded once the per-turn cap is hit" do
    turn = Llm::ChatTurn.new(chat: @chat)

    assert_raises(Llm::ChatTurn::ToolCallLimitExceeded) do
      (Llm::ChatTurn::MAX_TOOL_CALLS_PER_TURN + 1).times do |number|
        turn.send(:start_tool_call, FakeToolCall.new("tool_call_#{number}", "list_journal_entries"))
      end
    end
  end

  test "stops the turn when the tool-call limit is exceeded" do
    agent = ToolLoopAgent.new(@chat, Llm::ChatTurn::MAX_TOOL_CALLS_PER_TURN + 1)

    Llm::ChatTurn.new(chat: @chat, agent: agent).call

    assert_equal 1, agent.completions
    assert_equal [ "I stopped after reaching my tool-call limit for this turn. Please send a follow-up message to continue." ],
      @chat.visible_messages.pluck(:content)
  end

  test "lets a turn with tool calls under the limit complete normally" do
    agent = ToolLoopAgent.new(@chat, 5)

    Llm::ChatTurn.new(chat: @chat, agent: agent).call

    assert_equal 1, agent.completions
    assert_equal [ "Here you go." ], @chat.visible_messages.pluck(:content)
  end

  test "compacts before the turn when history is over budget" do
    stub_const(Llm::Chat, :CONTEXT_WINDOW_TOKENS, 4_000) do
      12.times { |number| build_fat_turn(number + 1) }
      agent = FakeAgent.new(@chat, [ "Here you go." ])
      compactor = Minitest::Mock.new
      compactor.expect(:call, true)

      Llm::ChatTurn.new(chat: @chat, agent: agent, compactor: compactor).call
      compactor.verify

      assert_equal "Here you go.", @chat.visible_messages.pluck(:content).last
    end
  end

  test "leaves history untouched when it fits the budget" do
    3.times do |number|
      @chat.llm_messages.create!(role: "user", content: "user #{number}")
      @chat.llm_messages.create!(role: "assistant", content: "assistant #{number}")
    end
    agent = FakeAgent.new(@chat, [ "Here you go." ])
    compactor = Object.new
    compactor.define_singleton_method(:call) { flunk "must not compact when history fits" }

    Llm::ChatTurn.new(chat: @chat, agent: agent, compactor: compactor).call

    assert_equal "Here you go.", @chat.visible_messages.pluck(:content).last
  end

  test "retries a repeated reversal question with a directive after the user approved" do
    entry = post_journal_entry!(
      @workspace,
      debit_account: @expense,
      credit_account: @cash,
      amount_kobo: 250_000
    )
    @chat.llm_messages.create!(role: "user", content: "Can we reverse the transport payment?")
    @chat.llm_messages.create!(role: "assistant", content: "I found the latest posted entry: ₦2,500 for transport on 17 August 2026. Do you want me to prepare a reversal for this entry?")
    @chat.llm_messages.create!(role: "user", content: "yes, go ahead")
    question = "I found the latest posted entry: ₦2,500 for transport on 17 August 2026. Do you want me to prepare a reversal for this entry?"
    agent = FakeAgent.new(@chat, [ question, "Reversal proposal created." ])

    Llm::ChatTurn.new(chat: @chat, agent: agent).call

    assert_equal 2, agent.completions
    assert @chat.llm_messages.where(role: "system").pluck(:content).any? do |content|
      content.include?("CONFIRMED REVERSAL for journal entry #{entry.id}")
    end
    assert_equal "Reversal proposal created.", @chat.visible_messages.pluck(:content).last
  end

  test "does not fire the reversal directive when the user did not confirm" do
    entry = post_journal_entry!(
      @workspace,
      debit_account: @expense,
      credit_account: @cash,
      amount_kobo: 250_000
    )
    @chat.llm_messages.create!(role: "user", content: "Can we reverse the transport payment?")
    @chat.llm_messages.create!(role: "assistant", content: "I found the latest posted entry: ₦2,500 for transport on 17 August 2026. Do you want me to prepare a reversal for this entry?")
    @chat.llm_messages.create!(role: "user", content: "Which entry do you mean?")
    agent = FakeAgent.new(@chat, [ "Here you go." ])

    Llm::ChatTurn.new(chat: @chat, agent: agent).call

    assert_equal 1, agent.completions
    refute @chat.llm_messages.where(role: "system").pluck(:content).any? do |content|
      content.include?("CONFIRMED REVERSAL for journal entry #{entry.id}")
    end
  end

  test "does not fire the reversal directive when propose_reversal was already attempted" do
    entry = post_journal_entry!(
      @workspace,
      debit_account: @expense,
      credit_account: @cash,
      amount_kobo: 250_000
    )
    @chat.llm_messages.create!(role: "user", content: "Can we reverse the transport payment?")
    @chat.llm_messages.create!(role: "assistant", content: "I found the latest posted entry: ₦2,500 for transport on 17 August 2026. Do you want me to prepare a reversal for this entry?")
    @chat.llm_messages.create!(role: "user", content: "yes")
    agent = ReversalToolAgent.new(@chat, "Do you want me to prepare a reversal for this entry?")

    Llm::ChatTurn.new(chat: @chat, agent: agent).call

    assert_equal 1, agent.completions
    refute @chat.llm_messages.where(role: "system").pluck(:content).any? do |content|
      content.include?("CONFIRMED REVERSAL for journal entry #{entry.id}")
    end
  end
end
