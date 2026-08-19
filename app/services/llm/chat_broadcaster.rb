class Llm::ChatBroadcaster
  def initialize(chat)
    @chat = chat
  end

  def append_assistant_chunk(content)
    @chat.llm_messages.last.broadcast_append_chunk(content)
  end

  def remove_empty_assistant_messages
    @chat.llm_messages.where(role: "assistant")
      .where("content IS NULL OR TRIM(content) = ''")
      .find_each do |message|
        message.broadcast_remove_to(stream, target: "llm_message_#{message.id}")
        message.destroy! if message.llm_tool_calls.none?
      end
  end

  def tool_running(tool_call)
    Turbo::StreamsChannel.broadcast_append_to stream,
      target: "llm_messages",
      partial: "llm/messages/tool_execution",
      locals: { tool_call_id: tool_call.id, tool_name: tool_call.name, state: :running }
  end

  def tool_completed(tool_call, result)
    Turbo::StreamsChannel.broadcast_replace_to stream,
      target: "tool_call_#{tool_call.id}",
      partial: "llm/messages/tool_execution",
      locals: { tool_call_id: tool_call.id, tool_name: tool_call.name, state: :completed, output: result }
  end

  def tool_append_completed(tool_call, result)
    Turbo::StreamsChannel.broadcast_append_to stream,
      target: "llm_messages",
      partial: "llm/messages/tool_execution",
      locals: { tool_call_id: tool_call.id, tool_name: tool_call.name, state: :completed, output: result }
  end

  def remove_tool_call(tool_call)
    Turbo::StreamsChannel.broadcast_remove_to stream, target: "tool_call_#{tool_call.id}"
  end

  def replace_tool_with_proposal(tool_call, proposal)
    partial = Llm::MessagesHelper::PROPOSAL_PARTIALS.fetch(proposal.proposal_type)
    Turbo::StreamsChannel.broadcast_replace_to stream,
      target: "tool_call_#{tool_call.id}",
      partial: partial,
      locals: { proposal: proposal }
  end

  def remove_proposal(proposal)
    Turbo::StreamsChannel.broadcast_remove_to stream, target: "proposal_#{proposal.id}"
  end

  def title(text)
    Turbo::StreamsChannel.broadcast_update_to stream, target: "llm_chat_#{@chat.id}_title", content: text
  end

  def remove_pending
    @chat.broadcast_remove_to stream, target: "llm_chat_#{@chat.id}_pending"
  end

  def pending
    Turbo::StreamsChannel.broadcast_replace_to stream,
      target: "llm_chat_#{@chat.id}_pending",
      partial: "llm/messages/pending",
      locals: { llm_chat: @chat }
  end

  def compacting
    Turbo::StreamsChannel.broadcast_replace_to stream,
      target: "llm_chat_#{@chat.id}_pending",
      partial: "llm/messages/compacting",
      locals: { llm_chat: @chat }
  end

  private

  def stream
    "llm_chat_#{@chat.id}"
  end
end
