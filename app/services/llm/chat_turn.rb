class Llm::ChatTurn
  def initialize(chat:, content:)
    @chat = chat
    @content = content
    @broadcaster = Llm::ChatBroadcaster.new(chat)
    @proposal_publisher = Llm::ProposalPublisher.new(chat)
  end

  def call
    agent = LedgerAgent.new(chat: @chat)
    current_tool_call = nil

    agent.before_tool_call do |tool_call|
      @broadcaster.remove_empty_assistant_messages
      current_tool_call = tool_call
      @broadcaster.tool_running(tool_call)
    end

    agent.after_tool_result do |result|
      if result.is_a?(Hash) && result[:proposal]
        @proposal_publisher.publish(tool_call: current_tool_call, result: result)
      else
        @broadcaster.tool_completed(current_tool_call, result)
      end
      current_tool_call = nil
    end

    agent.ask(@content) do |chunk|
      @broadcaster.append_assistant_chunk(chunk.content) if chunk.content.present?
    end

    @broadcaster.remove_empty_assistant_messages
  ensure
    @broadcaster.remove_pending
  end
end
