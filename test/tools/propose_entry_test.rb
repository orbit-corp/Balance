require "test_helper"

class ProposeEntryTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :uncategorized_expense)
  end

  test "proposes a balanced entry for a clear transaction" do
    result = execute_tool("I paid ₦2,500 cash for office supplies today.")

    assert result[:proposal]
    assert_equal "user_provided", result.dig(:entry_data, "amount_source")
  end

  test "resolves an account_name that already exists" do
    income = Account.for_role!(@workspace, :uncategorized_income)
    savings = Account.for_role!(@workspace, :savings)

    result = execute_tool_with_lines("My salary was 300k this month.", [
      { account_name: "Cash", side: "debit", amount_naira: "245000" },
      { account_name: "Savings", side: "debit", amount_naira: "55000" },
      { account_name: "Uncategorized Income", side: "credit", amount_naira: "300000" }
    ])

    assert result[:proposal]
    account_ids = result.dig(:entry_data, "lines").pluck("account_id")
    assert_includes account_ids, @cash.id
    assert_includes account_ids, income.id
    assert_includes account_ids, savings.id
  end

  test "refuses when a recommended account does not exist and lists it with the catalog type" do
    result = execute_tool_with_lines("My salary was 300k this month.", [
      { account_name: "Cash", side: "debit", amount_naira: "245000" },
      { account_name: "Groceries & Food", side: "debit", amount_naira: "35000" },
      { account_name: "Rent & Housing", side: "debit", amount_naira: "20000" },
      { account_name: "Salary & Wages", side: "credit", amount_naira: "300000" }
    ])

    assert_nil result[:proposal]
    assert_includes result[:error], "I couldn't record this transaction because the necessary accounts to do so are insufficient."
    assert_includes result[:error], "Groceries & Food (expense)"
    assert_includes result[:error], "Rent & Housing (expense)"
    assert_includes result[:error], "Salary & Wages (income)"
    refute_includes result[:error], "Cash"
  end

  test "refuses when a non-catalog account does not exist and falls back to a side-based type" do
    result = execute_tool_with_lines("I lent my friend 5k.", [
      { account_name: "Loans to Friends", side: "debit", amount_naira: "5000" },
      { account_name: "Cash", side: "credit", amount_naira: "5000" }
    ])

    assert_nil result[:proposal]
    assert_includes result[:error], "Loans to Friends (expense)"
  end

  test "refuses when only some lines reference missing accounts" do
    result = execute_tool_with_lines("My salary was 300k this month.", [
      { account_id: @cash.id, side: "debit", amount_naira: "245000" },
      { account_name: "Groceries & Food", side: "debit", amount_naira: "35000" },
      { account_name: "Rent & Housing", side: "debit", amount_naira: "20000" },
      { account_name: "Salary & Wages", side: "credit", amount_naira: "300000" }
    ])

    assert_nil result[:proposal]
    assert_includes result[:error], "Groceries & Food (expense)"
    assert_includes result[:error], "Rent & Housing (expense)"
    assert_includes result[:error], "Salary & Wages (income)"
  end

  test "rejects a line that has both an account_id and an account_name" do
    result = execute_tool_with_lines("I paid ₦2,500 for supplies.", [
      { account_id: @expense.id, account_name: "Supplies", side: "debit", amount_naira: "2500" },
      { account_id: @cash.id, side: "credit", amount_naira: "2500" }
    ])

    assert_nil result[:proposal]
    assert_equal "each line must specify either an account_id or an account_name, not both", result[:error]
  end

  test "rejects a line with neither an account_id nor an account_name" do
    result = execute_tool_with_lines("I paid ₦2,500 for supplies.", [
      { side: "debit", amount_naira: "2500" },
      { account_id: @cash.id, side: "credit", amount_naira: "2500" }
    ])

    assert_nil result[:proposal]
    assert_equal "each line needs an account_id or an account_name", result[:error]
  end

  test "handles string-keyed lines the way the model sends them" do
    result = execute_tool_with_lines("My salary was 300k this month.", [
      { "account_id" => @cash.id, "side" => "debit", "amount_naira" => "245000" },
      { "account_name" => "Groceries & Food", "side" => "debit", "amount_naira" => "35000" },
      { "account_name" => "Rent & Housing", "side" => "debit", "amount_naira" => "20000" },
      { "account_name" => "Salary & Wages", "side" => "credit", "amount_naira" => "300000" }
    ])

    assert_nil result[:proposal]
    assert_includes result[:error], "Groceries & Food (expense)"
    assert_includes result[:error], "Rent & Housing (expense)"
    assert_includes result[:error], "Salary & Wages (income)"
  end

  test "returns a clean error when a line is an array, not an object" do
    result = execute_tool_with_lines("I paid ₦2,500 for supplies.", [
      [ "0", { "account_id" => @expense.id, "side" => "debit", "amount_naira" => "2500" } ],
      { "account_id" => @cash.id, "side" => "credit", "amount_naira" => "2500" }
    ])

    assert_nil result[:proposal]
    assert_equal "each line must be an object with an account_id or an account_name", result[:error]
  end

  test "returns a clean error when lines is a hash keyed by index" do
    result = execute_tool_with_lines("I paid ₦2,500 for supplies.", {
      "0" => { "account_id" => @expense.id, "side" => "debit", "amount_naira" => "2500" },
      "1" => { "account_id" => @cash.id, "side" => "credit", "amount_naira" => "2500" }
    })

    assert_nil result[:proposal]
    assert_equal "each line must be an object with an account_id or an account_name", result[:error]
  end

  private

  def execute_tool(prompt)
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

  def execute_tool_with_lines(prompt, lines)
    chat = stub_llm_chat(workspace: @workspace, prompt: prompt)

    ProposeEntry.new(chat).execute(
      description: "Salary",
      entry_date: Date.current.to_s,
      lines: lines
    )
  end
end
