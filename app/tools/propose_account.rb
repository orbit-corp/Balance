class ProposeAccount < RubyLLM::Tool
  description "Propose one or more missing ledger accounts for the user to review. This never creates an account. " \
              "Call it only after the transaction is fully understood, list_accounts shows the accounts are missing, " \
              "and the proposed taxonomy is valid for the workspace."

  params do
    string :reason, description: "plain-language reason these accounts are needed for the transaction"
    array :accounts, description: "missing accounts to present together for approval" do
      object do
        string :name, description: "clear account name"
        string :base_type, enum: %w[asset liability equity income expense]
        string :account_type, description: "account type from the workspace taxonomy"
        string :detail_type, description: "detail type from the workspace taxonomy"
      end
    end
  end

  def initialize(chat)
    @chat = chat
    @workspace = chat.workspace
  end

  def execute(reason:, accounts:)
    unless account_lookup_for_active_turn?
      return { error: "Inspect the active workspace accounts and recommendations before proposing an account." }
    end

    draft = Llm::AccountCreationProposal.from_tool(workspace: @workspace, reason: reason, accounts: accounts)
    return { error: draft.errors.join(", ") } if draft.invalid?

    grounding = Llm::AccountProposalGrounding.new(chat: @chat, data: draft.data)
    if grounding.invalid?
      return {
        error: "That account proposal is not grounded in the active request: #{grounding.errors.join(', ')}.",
        grounding_error: true
      }
    end

    halt({
      proposal: true,
      proposed_action: "account_creation",
      entry_data: draft.data,
      message: "Account proposal created for review."
    })
  end

  private

  def account_lookup_for_active_turn?
    return true unless @chat.respond_to?(:persisted?) && @chat.persisted?

    active_turn = @chat.active_turn
    return true unless active_turn

    Llm::ToolCall.joins(:llm_message)
      .where(name: "list_accounts", llm_messages: { llm_turn_id: active_turn.id })
      .exists?
  end
end
