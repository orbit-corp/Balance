class Llm::ProposalPublisher
  def initialize(chat:, broadcaster: Llm::ChatBroadcaster.new(chat))
    @chat = chat
    @broadcaster = broadcaster
  end

  def publish(tool_call:, result:)
    proposal, superseded = create_proposal!(tool_call: tool_call, result: result)
    superseded.each { |old_proposal| @broadcaster.remove_proposal(old_proposal) }
    @broadcaster.replace_tool_with_proposal(tool_call, proposal)
  end

  private

  def create_proposal!(tool_call:, result:)
    @chat.with_lock do
      proposal_type = result.fetch(:proposed_action)
      superseded = @chat.proposals.proposed.by_type(proposal_type).to_a
      version = (@chat.proposals.by_type(proposal_type).maximum(:version) || 0) + 1
      superseded.each(&:supersede!)

      proposal = @chat.proposals.create!(
        workspace: @chat.workspace,
        llm_message_id: message_id_for(tool_call),
        proposal_type: proposal_type,
        version: version,
        data: result.fetch(:entry_data)
      )

      [ proposal, superseded ]
    end
  end

  def message_id_for(tool_call)
    @chat.llm_messages
      .joins(:llm_tool_calls)
      .where(llm_tool_calls: { tool_call_id: tool_call.id })
      .pick(:id)
  end
end
