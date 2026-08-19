require "test_helper"
require "json"

class LedgerHarnessReplayTest < ActiveSupport::TestCase
  CASES = JSON.parse(
    Rails.root.join("test/fixtures/files/ledger_harness_cases.json").read
  ).freeze

  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :other_expense)
  end

  test "corpus declares the expected safe outcomes" do
    assert_equal(
      %w[insufficient_accounts lookup proposal recording_status refusal reversal_request review_required],
      CASES.map { |test_case| test_case.fetch("expected") }.uniq.sort
    )
    assert CASES.all? { |test_case| test_case.fetch("prompt").present? }
    refute CASES.any? { |test_case| test_case.fetch("prompt").match?(/ocr/i) }
  end

  test "proposal cases produce a proposal" do
    CASES.select { |test_case| test_case.fetch("expected") == "proposal" }.each do |test_case|
      result = propose(test_case.fetch("prompt"))

      assert result[:proposal], test_case.fetch("name")
    end
  end

  test "insufficient-account cases refuse with the accounts that should be created" do
    CASES.select { |test_case| test_case.fetch("expected") == "insufficient_accounts" }.each do |test_case|
      chat = stub_llm_chat(workspace: @workspace, prompt: test_case.fetch("prompt"))
      result = ProposeEntry.new(chat).execute(
        description: "Salary",
        entry_date: Date.current.to_s,
        lines: [
          { account_name: "Cash", side: "debit", amount_naira: "245000" },
          { account_name: "Pension", side: "debit", amount_naira: "35000" },
          { account_name: "Tax", side: "debit", amount_naira: "20000" },
          { account_name: "Salary Income", side: "credit", amount_naira: "300000" }
        ]
      )

      assert_nil result[:proposal], test_case.fetch("name")
      assert_includes result[:error], "I couldn't record this transaction because the necessary accounts to do so are insufficient.", test_case.fetch("name")
      assert_includes result[:error], "Pension (expense)", test_case.fetch("name")
      assert_includes result[:error], "Tax (expense)", test_case.fetch("name")
      assert_includes result[:error], "Salary Income (income)", test_case.fetch("name")
    end
  end

  private

  def propose(prompt)
    chat = stub_llm_chat(workspace: @workspace, prompt: prompt)

    ProposeEntry.new(chat).execute(
      description: "Office supplies",
      entry_date: Date.current.to_s,
      lines: [
        { account_id: @expense.id, side: "debit", amount_naira: "2500" },
        { account_id: @cash.id, side: "credit", amount_naira: "2500" }
      ]
    )
  end
end
