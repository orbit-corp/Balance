require "test_helper"

class ProposeEntryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :uncategorized_expense)
    @tool = ProposeEntry.new(stub_llm_chat(workspace: @workspace, prompt: "Paid ₦2,500 cash for supplies"))
  end

  test "proposes a balanced entry using existing account IDs" do
    result = execute_tool

    assert result[:proposal]
    assert_equal "journal_entry", result[:proposed_action]
    assert_equal [ @expense.id, @cash.id ], result.dig(:entry_data, "lines").pluck("account_id")
  end

  test "rejects a missing account ID instead of bypassing account approval" do
    result = execute_tool(lines: [
      { side: "debit", amount_naira: "2500" },
      { account_id: @cash.id, side: "credit", amount_naira: "2500" }
    ])

    refute result[:proposal]
    assert_includes result[:error], "Journal entry lines account must exist"
  end

  test "rejects an account from another workspace" do
    other_cash = Account.for_role!(workspaces(:bola_shop), :cash)
    result = execute_tool(lines: [
      { account_id: @expense.id, side: "debit", amount_naira: "2500" },
      { account_id: other_cash.id, side: "credit", amount_naira: "2500" }
    ])

    refute result[:proposal]
    assert_includes result[:error], "Journal entry lines account must exist"
  end

  test "rejects an unbalanced entry" do
    result = execute_tool(lines: [
      { account_id: @expense.id, side: "debit", amount_naira: "2500" },
      { account_id: @cash.id, side: "credit", amount_naira: "2000" }
    ])

    refute result[:proposal]
    assert_includes result[:error], "Total debits (2500.00) must equal total credits (2000.00)"
  end

  private

  def execute_tool(lines: nil)
    @tool.execute(
      description: "Office supplies",
      entry_date: Date.current.to_s,
      lines: lines || [
        { account_id: @expense.id, side: "debit", amount_naira: "2500" },
        { account_id: @cash.id, side: "credit", amount_naira: "2500" }
      ]
    )
  end
end
