require "test_helper"

class ProposalTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :general_expense)
    @chat = Llm::Chat.create!(
      workspace: @workspace,
      llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Test model"),
      title: "Test chat"
    )
    @proposal = @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "journal_entry",
      version: 1,
      data: {
        "description" => "Office supplies",
        "entry_date" => Date.current.to_s,
        "lines" => [
          { "account_id" => @expense.id, "side" => "debit", "amount_kobo" => 250_000 },
          { "account_id" => @cash.id, "side" => "credit", "amount_kobo" => 250_000 }
        ]
      }
    )
  end

  test "confirm! posts the entry and marks the proposal confirmed" do
    assert_difference "JournalEntry.count", 1 do
      assert_nil @proposal.confirm!(draft: build_draft)
    end

    assert_equal "confirmed", @proposal.reload.status
    assert_not_nil @proposal.journal_entry
  end

  test "double-confirm posts exactly one entry" do
    assert_difference "JournalEntry.count", 1 do
      @proposal.confirm!(draft: build_draft)
      @proposal.confirm!(draft: build_draft)
    end

    assert_equal "confirmed", @proposal.reload.status
  end

  test "confirm! is a no-op once the proposal is no longer pending" do
    @proposal.confirm!(draft: build_draft)
    @proposal.update!(status: "dismissed", journal_entry: nil)

    assert_no_difference "JournalEntry.count" do
      assert_equal [], @proposal.confirm!(draft: build_draft)
    end

    assert_equal "dismissed", @proposal.reload.status
  end

  test "confirm! returns the draft errors without posting anything" do
    draft = build_draft(lines: [ { account_id: @expense.id, side: "debit", amount_naira: "2500" } ])

    assert_no_difference "JournalEntry.count" do
      result = @proposal.confirm!(draft: draft)
      assert_includes result, "Journal entry lines must contain at least two lines"
    end

    assert_equal "proposed", @proposal.reload.status
    assert_nil @proposal.journal_entry
  end

  test "confirm! does not post an unbalanced draft" do
    draft = build_draft(
      lines: [
        { account_id: @expense.id, side: "debit", amount_naira: "2500" },
        { account_id: @cash.id, side: "credit", amount_naira: "2000" }
      ]
    )

    assert_no_difference "JournalEntry.count" do
      result = @proposal.confirm!(draft: draft)
      assert_includes result, "debits and credits must balance"
    end

    assert_equal "proposed", @proposal.reload.status
  end

  test "confirm! refuses a draft whose account belongs to another workspace" do
    other_workspace = workspaces(:bola_shop)
    other_cash = Account.for_role!(other_workspace, :cash)

    draft = build_draft(
      lines: [
        { account_id: @expense.id, side: "debit", amount_naira: "2500" },
        { account_id: other_cash.id, side: "credit", amount_naira: "2500" }
      ]
    )

    assert_no_difference "JournalEntry.count" do
      result = @proposal.confirm!(draft: draft)
      assert_includes result, "Journal entry lines account must exist"
    end
  end

  private

  def build_draft(lines: nil)
    lines ||= [
      { account_id: @expense.id, side: "debit", amount_naira: "2500" },
      { account_id: @cash.id, side: "credit", amount_naira: "2500" }
    ]

    Llm::JournalEntryProposal.from_tool(
      workspace: @workspace,
      description: "Office supplies",
      entry_date: Date.current.to_s,
      lines: lines
    )
  end
end
