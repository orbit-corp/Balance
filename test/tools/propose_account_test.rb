require "test_helper"

class ProposeAccountTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @tool = ProposeAccount.new(stub_llm_chat(workspace: @workspace, prompt: "I paid rent"))
  end

  test "returns a reviewable proposal without creating an account" do
    assert_no_difference "Account.count" do
      @result = propose_rent
    end

    assert_instance_of RubyLLM::Tool::Halt, @result
    assert @result.content[:proposal]
    assert_equal "account_creation", @result.content[:proposed_action]
    assert_equal "Rent & Housing", @result.content.dig(:entry_data, "accounts", 0, "name")
  end

  test "validates the workspace taxonomy before presenting a proposal" do
    result = propose_rent(detail_type: "Made up")

    refute result[:proposal]
    assert_includes result[:error], "Detail type is not valid"
  end

  test "does not propose an account that already exists" do
    Account.create!(
      workspace: @workspace,
      name: "Rent & Housing",
      base_type: "expense",
      account_type: "Personal Outflows",
      detail_type: "Housing & Utilities"
    )

    result = propose_rent

    refute result[:proposal]
    assert_includes result[:error], "These accounts already exist: Rent & Housing"
  end

  test "requires account inspection during an active persisted turn" do
    chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Test model"),
      title: "Test chat"
    )
    message = chat.llm_messages.create!(role: "user", content: "I paid 2k rent")
    turn = chat.llm_turns.create!(user_message: message, allowed_tools: %w[list_accounts propose_account])
    chat.active_turn = turn
    tool = ProposeAccount.new(chat)

    blocked = tool.execute(
      reason: "Rent needs its own expense account.",
      accounts: [ rent_account ]
    )
    assert_includes blocked[:error], "Inspect the active workspace accounts"

    assistant = chat.llm_messages.create!(role: "assistant", content: "", response_turn: turn)
    assistant.llm_tool_calls.create!(tool_call_id: "lookup_1", name: "list_accounts", arguments: {})

    assert_instance_of RubyLLM::Tool::Halt, tool.execute(
      reason: "Rent needs its own expense account.",
      accounts: [ rent_account ]
    )
  end

  private

  def propose_rent(**overrides)
    @tool.execute(
      reason: "Rent needs its own expense account.",
      accounts: [ rent_account(**overrides) ]
    )
  end

  def rent_account(**overrides)
    {
      name: "Rent & Housing",
      base_type: "expense",
      account_type: "Personal Outflows",
      detail_type: "Housing & Utilities",
      **overrides
    }
  end
end
