require "test_helper"

class Llm::ProposalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:ada_store)
    @user = users(:one)
    sign_in_as(@user)

    @cash = Account.for_role!(@workspace, :cash)
    @expense = Account.for_role!(@workspace, :uncategorized_expense)
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
        "description" => "Gift to girlfriend",
        "entry_date" => Date.current.to_s,
        "lines" => [
          { "account_id" => @expense.id, "side" => "debit", "amount_kobo" => 200_000 },
          { "account_id" => @cash.id, "side" => "credit", "amount_kobo" => 200_000 }
        ]
      }
    )
  end

  test "update accepts the indexed lines hash" do
    patch chat_proposal_path(@chat, @proposal), params: { proposal: form_params }

    assert_redirected_to chat_path(@chat)
    assert_equal 2, @proposal.reload.data["lines"].size
  end

  test "confirm posts the entry when two lines are submitted" do
    assert_difference "JournalEntry.count", 1 do
      patch confirm_chat_proposal_path(@chat, @proposal), params: { proposal: form_params }
    end

    assert_redirected_to chat_path(@chat)
    assert_equal "confirmed", @proposal.reload.status
    assert_not_nil @proposal.journal_entry
    assert_equal 2, @proposal.journal_entry.journal_entry_lines.size
  end

  test "confirm with a single line reports an error and posts nothing" do
    params = form_params
    params[:lines].delete("1")

    assert_no_difference "JournalEntry.count" do
      patch confirm_chat_proposal_path(@chat, @proposal),
            params: { proposal: params },
            headers: { Accept: "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "An entry requires at least two lines", response.body
    assert_equal "proposed", @proposal.reload.status
  end

  test "a reversal proposal cannot be edited" do
    reversal = reversal_proposal
    original_data = reversal.data.deep_dup

    patch chat_proposal_path(@chat, reversal), params: { proposal: form_params }

    assert_redirected_to chat_path(@chat)
    assert_equal original_data, reversal.reload.data
  end

  test "confirming a reversal ignores crafted form changes" do
    reversal = reversal_proposal

    assert_difference "JournalEntry.count", 1 do
      patch confirm_chat_proposal_path(@chat, reversal), params: { proposal: form_params }
    end

    recorded = reversal.reload.journal_entry
    assert_equal @source_entry.id, recorded.reverses_journal_entry_id
    assert_equal "Reversal of journal entry #{@source_entry.id}: Lunch", recorded.description
    assert_equal 5_000, recorded.journal_entry_lines.find_by!(account: @cash).debit_kobo
    assert_equal 5_000, recorded.journal_entry_lines.find_by!(account: @expense).credit_kobo
  end

  test "confirming an account proposal creates the account and resumes the transaction" do
    user_message = @chat.llm_messages.create!(role: "user", content: "I paid 2000 rent in cash")
    session = @chat.llm_transaction_sessions.create!(
      facts: {
        "summary" => "Paid rent in cash",
        "amount" => "2000 NGN",
        "date" => Date.current.iso8601,
        "missing_facts" => [],
        "ready" => true
      },
      source_message_ids: [ user_message.id ]
    )
    source_turn = @chat.llm_turns.create!(
      user_message: user_message,
      llm_transaction_session: session,
      status: "completed",
      completed_at: Time.current
    )
    proposal_message = @chat.llm_messages.create!(role: "assistant", content: "", response_turn: source_turn)
    proposal = @chat.proposals.create!(
      workspace: @workspace,
      llm_message: proposal_message,
      proposal_type: "account_creation",
      version: 1,
      data: {
        "reason" => "Rent needs its own expense account.",
        "accounts" => [ {
          "name" => "Rent & Housing",
          "base_type" => "expense",
          "account_type" => "Personal Outflows",
          "detail_type" => "Housing & Utilities"
        } ]
      }
    )

    assert_difference "Account.count", 1 do
      assert_enqueued_with(job: LlmChatResponseJob, args: ->(args) { args.first == @chat.id && args.second.is_a?(Integer) }) do
        patch confirm_chat_proposal_path(@chat, proposal), headers: { Accept: "text/vnd.turbo-stream.html" }
      end
    end

    assert_response :success
    assert_match "Created and ready to use", response.body
    assert_equal "confirmed", proposal.reload.status
    assert_equal "Rent & Housing", proposal.data.dig("created_accounts", 0, "name")
    assert_match "ACCOUNT PROPOSAL APPROVED", @chat.llm_messages.where(role: "system").last.content

    resumed_turn = @chat.llm_turns.order(:id).last
    assert_equal "transaction", resumed_turn.intent
    assert_equal "continuation", resumed_turn.relationship
    assert_equal %w[list_accounts propose_entry], resumed_turn.allowed_tools
    assert resumed_turn.classification.dig("transaction", "ready")
    assert_empty resumed_turn.classification.dig("transaction", "missing_facts")
    assert_includes resumed_turn.context_message_ids, user_message.id
    assert_includes resumed_turn.context_message_ids, proposal_message.id
  end

  test "confirming a standalone account proposal does not start a transaction turn" do
    proposal = @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "account_creation",
      version: 1,
      data: {
        "reason" => "Track rent separately.",
        "accounts" => [ {
          "name" => "Rent & Housing",
          "base_type" => "expense",
          "account_type" => "Personal Outflows",
          "detail_type" => "Housing & Utilities"
        } ]
      }
    )

    assert_no_difference "Llm::Turn.count" do
      patch confirm_chat_proposal_path(@chat, proposal)
    end

    assert_equal "confirmed", proposal.reload.status
  end

  test "dismissing an account proposal creates nothing" do
    proposal = @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "account_creation",
      version: 1,
      data: {
        "reason" => "Rent needs its own expense account.",
        "accounts" => [ {
          "name" => "Rent & Housing",
          "base_type" => "expense",
          "account_type" => "Personal Outflows",
          "detail_type" => "Housing & Utilities"
        } ]
      }
    )

    assert_no_difference "Account.count" do
      patch dismiss_chat_proposal_path(@chat, proposal)
    end

    assert_equal "dismissed", proposal.reload.status
  end

  private

  def reversal_proposal
    @source_entry = @workspace.journal_entries.create!(
      description: "Lunch",
      entry_date: Date.current,
      journal_entry_lines_attributes: [
        { account: @expense, debit_kobo: 5_000, credit_kobo: 0 },
        { account: @cash, debit_kobo: 0, credit_kobo: 5_000 }
      ]
    )

    @chat.proposals.create!(
      workspace: @workspace,
      proposal_type: "journal_entry",
      version: 2,
      data: {
        "description" => "Reversal of journal entry #{@source_entry.id}: Lunch",
        "entry_date" => Date.current.to_s,
        "amount_source" => "existing_posted_entry",
        "reverses_journal_entry_id" => @source_entry.id,
        "lines" => [
          { "account_id" => @expense.id, "side" => "credit", "amount_kobo" => 5_000 },
          { "account_id" => @cash.id, "side" => "debit", "amount_kobo" => 5_000 }
        ]
      }
    )
  end

  def form_params
    {
      description: "Gift to girlfriend - N2,000 cash spent today",
      entry_date: Date.current.to_s,
      lines: {
        "0" => { account_id: @expense.id, side: "debit", amount_naira: "2000.00" },
        "1" => { account_id: @cash.id, side: "credit", amount_naira: "2000.00" }
      }
    }
  end
end
