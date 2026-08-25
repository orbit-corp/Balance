require "test_helper"

class ProposeReversalTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :uncategorized_expense)
    @entry = post_journal_entry!(
      @workspace,
      debit_account: @expense,
      credit_account: @cash,
      amount_kobo: 250_000
    )
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Test model"),
      title: "Test chat"
    )
  end

  test "refuses without a prior confirmation question" do
    result = execute

    assert_equal "I need your confirmation before I prepare a reversal. Please confirm you want to reverse journal entry #{@entry.id}.", result[:error]
  end

  test "proposes opposite lines once the assistant asked for confirmation" do
    ask_for_confirmation

    result = execute

    assert result[:proposal]
    assert_equal @entry.id, result.dig(:entry_data, "reverses_journal_entry_id")
    assert_equal %w[credit debit], result.dig(:entry_data, "lines").map { |line| line["side"] }
    assert_equal @entry.id, @workspace.journal_entries.find(@entry.id).id
  end

  test "rejects an entry from another workspace even after confirmation" do
    ask_for_confirmation
    other_workspace = workspaces(:bola_shop)
    other_chat = Llm::Chat.create!(
      workspace: other_workspace,
      llm_model: @chat.llm_model,
      title: "Test chat"
    )
    other_chat.llm_messages.create!(role: "assistant", content: "Do you want me to prepare a reversal for this entry?")

    result = ProposeReversal.new(other_chat).execute(entry_id: @entry.id)

    assert_equal "That journal entry does not exist in this workspace.", result[:error]
  end

  test "rejects an entry that already has a reversal" do
    @entry.reverse!
    ask_for_confirmation

    result = execute

    assert_equal "That journal entry has already been reversed.", result[:error]
    assert_nil result[:proposal]
  end

  private

  def ask_for_confirmation
    @chat.llm_messages.create!(role: "assistant", content: "Do you want me to prepare a reversal for this entry?")
    @chat.llm_messages.create!(role: "assistant", content: "")
  end

  def execute
    ProposeReversal.new(@chat).execute(entry_id: @entry.id)
  end
end
