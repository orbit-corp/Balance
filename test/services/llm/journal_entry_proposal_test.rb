require "test_helper"

class LlmJournalEntryProposalTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :other_expense)
  end

  test "parses decimal naira exactly into kobo" do
    draft = build_draft(amount: "2500.10")

    assert draft.valid?
    assert_equal 250_010, draft.data.fetch("lines").first.fetch("amount_kobo")
  end

  test "rejects the same account on both sides" do
    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Invalid transfer",
      entry_date: Date.current.to_s,
      lines: [
        { account_id: @cash.id, side: "debit", amount_naira: "100" },
        { account_id: @cash.id, side: "credit", amount_naira: "100" }
      ]
    )

    assert_includes draft.errors, "the same account cannot be both debited and credited"
  end

  test "rejects duplicate identical lines" do
    draft = Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Duplicate lines",
      entry_date: Date.current.to_s,
      lines: [
        { account_id: @expense.id, side: "debit", amount_naira: "100" },
        { account_id: @expense.id, side: "debit", amount_naira: "100" },
        { account_id: @cash.id, side: "credit", amount_naira: "200" }
      ]
    )

    assert_includes draft.errors, "duplicate journal lines are not allowed"
  end

  test "rejects future dates" do
    draft = build_draft(amount: "100", entry_date: (Date.current + 1.day).to_s)

    assert_includes draft.errors, "Entry date cannot be in the future"
  end

  private

  def build_draft(amount:, entry_date: Date.current.to_s)
    Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Office expense",
      entry_date: entry_date,
      lines: [
        { account_id: @expense.id, side: "debit", amount_naira: amount },
        { account_id: @cash.id, side: "credit", amount_naira: amount }
      ]
    )
  end
end
