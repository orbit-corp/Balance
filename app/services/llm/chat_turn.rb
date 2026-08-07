class Llm::ChatTurn
  def initialize(chat:)
    @chat = chat
    @broadcaster = Llm::ChatBroadcaster.new(chat)
    @publisher = Llm::ProposalPublisher.new(chat: chat, broadcaster: @broadcaster)
  end

  def call
    agent = LedgerAgent.new(chat: @chat)
    agent.before_tool_call { |tool_call| start_tool_call(tool_call) }
    agent.after_tool_result { |result| finish_tool_call(result) }

    agent.complete do |chunk|
      @broadcaster.append_assistant_chunk(chunk.content) if chunk.content.present?
    end

    @broadcaster.remove_empty_assistant_messages
  ensure
    @broadcaster.remove_pending
  end

  private

  def start_tool_call(tool_call)
    @broadcaster.remove_empty_assistant_messages
    @current_tool_call = tool_call
    @broadcaster.tool_running(tool_call)
  end

  def finish_tool_call(result)
    if proposal?(result)
      @publisher.publish(tool_call: @current_tool_call, result: result)
    else
      @broadcaster.tool_completed(@current_tool_call, result)
    end

    @current_tool_call = nil
  end

  def proposal?(result)
    result.is_a?(Hash) && result[:proposal]
  end
end
