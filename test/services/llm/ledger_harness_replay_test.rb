require "test_helper"
require "json"

class LedgerHarnessReplayTest < ActiveSupport::TestCase
  CASES = JSON.parse(Rails.root.join("test/fixtures/files/ledger_harness_cases.json").read).freeze
  OUTCOMES = %w[account_creation_proposal clarification journal_entry_proposal lookup recording_status refusal reversal_request review_required].freeze

  setup do
    @workspace = workspaces(:ada_store)
    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :uncategorized_expense)
    post_journal_entry!(@workspace, debit_account: @expense, credit_account: @cash, amount_kobo: 200_000)
    create_pending_proposal
  end

  test "corpus has valid, uniquely named trajectories" do
    ids = CASES.map { |test_case| test_case.fetch("id") }

    assert_equal ids.uniq, ids
    assert_equal OUTCOMES, CASES.map { |test_case| test_case.dig("expected", "outcome") }.uniq.sort
    assert CASES.all? { |test_case| test_case.fetch("prompt").present? }
    assert CASES.select { |test_case| test_case["source_example"] }.all? { |test_case| (1..17).cover?(test_case.fetch("source_example")) }
    assert CASES.select { |test_case| %w[clarification refusal reversal_request].include?(test_case.dig("expected", "outcome")) }
      .all? { |test_case| test_case.dig("expected", "response_contract").present? }
  end

  test "recorded trajectories execute real tools and satisfy each outcome" do
    CASES.each do |test_case|
      results = execute_trajectory(test_case)
      expected = test_case.fetch("expected")
      calls = Array(test_case["recorded_calls"])

      assert_equal expected.fetch("tool_sequence"), calls.pluck("tool"), test_case.fetch("id")
      assert_outcome(test_case, results)
    end
  end

  test "proposal trajectories never post journal entries" do
    proposal_cases = CASES.select { |test_case| %w[journal_entry_proposal review_required account_creation_proposal].include?(test_case.dig("expected", "outcome")) }

    assert_no_difference "JournalEntry.count" do
      proposal_cases.each { |test_case| execute_trajectory(test_case) }
    end
  end

  private

  def execute_trajectory(test_case)
    chat = chat_for(test_case)

    Array(test_case["recorded_calls"]).map do |call|
      arguments = resolve_arguments(call["arguments"] || {})
      tool_for(call.fetch("tool"), chat).execute(**arguments.symbolize_keys)
    end
  end

  def tool_for(name, chat)
    {
      "list_accounts" => ListAccounts.new(@workspace),
      "propose_account" => ProposeAccount.new(chat),
      "propose_entry" => ProposeEntry.new(chat),
      "propose_reversal" => ProposeReversal.new(chat),
      "list_journal_entries" => ListJournalEntries.new(@workspace),
      "check_proposal_status" => CheckProposalStatus.new(@workspace)
    }.fetch(name)
  end

  def chat_for(test_case)
    messages = Array(test_case["prior_messages"]).map do |message|
      FakeMessage.new(message.fetch("role"), message.fetch("content"))
    end
    messages << FakeMessage.new("user", test_case.fetch("prompt"))
    stub_llm_chat_with_messages(workspace: @workspace, messages: messages)
  end

  def resolve_arguments(arguments)
    arguments.deep_dup.tap do |resolved|
      resolved["entry_date"] = Date.current.to_s if resolved["entry_date"] == "today"
      resolved["entry_id"] = @workspace.journal_entries.order(entry_date: :desc, id: :desc).pick(:id) if resolved["entry_id"] == "latest_posted"
      Array(resolved["lines"]).each do |line|
        role = line.delete("account_role")
        line["account_id"] = Account.for_role!(@workspace, role).id if role
      end
    end
  end

  def assert_outcome(test_case, results)
    outcome = test_case.dig("expected", "outcome")
    result = results.last
    message = test_case.fetch("id")

    case outcome
    when "journal_entry_proposal", "review_required"
      assert result[:proposal], message
      assert_equal "journal_entry", result[:proposed_action], message
    when "account_creation_proposal"
      assert result[:proposal], message
      assert_equal "account_creation", result[:proposed_action], message
    when "lookup", "recording_status"
      assert_kind_of Array, result, message
      assert result.any?, message
    when "reversal_request"
      assert_kind_of Array, result, message
      assert_response_contract(test_case)
    when "clarification", "refusal"
      assert_empty results, message
      assert_response_contract(test_case)
    else
      flunk "Unknown harness outcome: #{outcome}"
    end
  end

  def assert_response_contract(test_case)
    result = Llm::Harness::ResponseContract.new(
      response: test_case.fetch("recorded_response"),
      contract: test_case.dig("expected", "response_contract")
    )

    assert result.valid?, "#{test_case.fetch("id")}: #{result.errors.join(", ")}"
  end

  def create_pending_proposal
    @workspace.proposals.create!(
      llm_chat: Llm::Chat.create!(
        workspace: @workspace,
        llm_model: Llm::Model.create!(provider: "test", model_id: RubyLLM.config.default_model, name: "Harness model"),
        title: "Harness"
      ),
      proposal_type: "journal_entry",
      data: {
        "description" => "Pending expense",
        "entry_date" => Date.current.to_s,
        "lines" => [
          { "account_id" => @expense.id, "side" => "debit", "amount_kobo" => 100_000 },
          { "account_id" => @cash.id, "side" => "credit", "amount_kobo" => 100_000 }
        ]
      }
    )
  end
end
