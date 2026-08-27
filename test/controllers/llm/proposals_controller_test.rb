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

  test "confirming an account proposal creates the account and resumes the transaction" do
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
