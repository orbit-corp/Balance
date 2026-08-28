require "test_helper"

class ConfirmProposalTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :uncategorized_expense)
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Confirmation test"),
      title: "Confirmation test"
    )
    @proposal = @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "journal_entry",
      version: 1,
      data: {
        "description" => "Cash expense",
        "entry_date" => Date.current.iso8601,
        "lines" => [
          { "account_id" => @expense.id, "side" => "debit", "amount_kobo" => 200_000 },
          { "account_id" => @cash.id, "side" => "credit", "amount_kobo" => 200_000 }
        ]
      }
    )
  end

  test "records the pending journal proposal exactly once" do
    tool = ConfirmProposal.new(@chat)

    assert_difference "JournalEntry.count", 1 do
      result = tool.execute
      assert_equal "confirmed", result[:status]
      assert_equal @proposal.id, result[:proposal_id]
    end

    assert_no_difference "JournalEntry.count" do
      result = tool.execute
      assert result[:already_recorded]
      assert_equal @proposal.reload.journal_entry_id, result[:journal_entry_id]
    end
  end

  test "does not confirm an account proposal" do
    @proposal.destroy!
    @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "account_creation",
      version: 1,
      data: { "reason" => "Track rent", "accounts" => [] }
    )

    result = ConfirmProposal.new(@chat).execute

    assert_includes result[:error], "no journal-entry proposal"
  end
end
