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
    result = result.content

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

  test "requires every account created for the resumed transaction" do
    model = Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Test model")
    chat = Llm::Chat.create!(workspace: @workspace, llm_model: model, title: "Resumed transaction")
    tax = @workspace.accounts.create!(
      name: "Tax Expense",
      base_type: "expense",
      account_type: "Personal Outflows",
      detail_type: "Living & Daily Needs"
    )
    chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "account_creation",
      status: "confirmed",
      data: {
        "reason" => "Track tax separately",
        "accounts" => [],
        "created_accounts" => [ { "id" => tax.id, "name" => tax.name } ]
      }
    )
    message = chat.llm_messages.create!(role: "system", content: "Continue the pending transaction")
    chat.active_turn = chat.llm_turns.create!(user_message: message)

    result = ProposeEntry.new(chat).execute(
      description: "Salary with tax",
      lines: [
        { account_id: @expense.id, side: "debit", amount_naira: "2500" },
        { account_id: @cash.id, side: "credit", amount_naira: "2500" }
      ]
    )

    assert_includes result[:error], "Tax Expense (id #{tax.id})"

    corrected = ProposeEntry.new(chat).execute(
      description: "Salary with tax",
      lines: [
        { "account_id" => @expense.id, "side" => "debit", "amount_naira" => "2000" },
        { "account_id" => tax.id, "side" => "debit", "amount_naira" => "500" },
        { "account_id" => @cash.id, "side" => "credit", "amount_naira" => "2500" }
      ]
    )

    assert_instance_of RubyLLM::Tool::Halt, corrected
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
