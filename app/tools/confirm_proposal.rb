class ConfirmProposal < RubyLLM::Tool
  description "Record the current reviewable journal-entry proposal after the user explicitly approves it. " \
              "Use only for a direct instruction such as 'record it' or 'approve this entry'. " \
              "This is idempotent and never confirms an account-creation proposal."

  def initialize(chat)
    @chat = chat
  end

  def execute
    proposal = current_proposal
    unless proposal
      recorded = last_recorded_proposal
      return recorded_result(recorded, already_recorded: true) if recorded

      return { error: "There is no journal-entry proposal awaiting approval." }
    end

    draft = Llm::JournalEntryProposal.new(workspace: @chat.workspace, data: proposal.data)
    errors = proposal.confirm!(draft: draft)
    return { error: errors.join(", ") } if errors.present?

    proposal.reload
    Llm::ChatBroadcaster.new(@chat).proposal_updated(proposal)

    recorded_result(proposal)
  rescue ActiveRecord::RecordInvalid => error
    { error: error.record.errors.full_messages.join(", ") }
  end

  private

  def recorded_result(proposal, already_recorded: false)
    {
      message: "Journal entry recorded.",
      proposal_id: proposal.id,
      status: proposal.status,
      journal_entry_id: proposal.journal_entry_id,
      description: proposal.description,
      entry_date: proposal.entry_date,
      already_recorded: already_recorded
    }
  end

  def current_proposal
    scoped = @chat.proposals.proposed.by_type("journal_entry")
    session = @chat.active_turn&.llm_transaction_session
    if session
      scoped = scoped.joins(:llm_message)
        .where(llm_messages: { llm_turn_id: session.llm_turns.select(:id) })
    end

    scoped.order(version: :desc, id: :desc).first ||
      @chat.proposals.proposed.by_type("journal_entry").order(version: :desc, id: :desc).first
  end

  def last_recorded_proposal
    @chat.proposals.by_type("journal_entry").where(status: "confirmed").order(version: :desc, id: :desc).first
  end
end
