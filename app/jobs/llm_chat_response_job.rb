class LlmChatResponseJob < ApplicationJob
  INSTRUCTIONS = <<~PROMPT
    You help record personal financial transactions into a double-entry ledger.
    Use the list_accounts tool to see what accounts exist before answering.
    When you know how to record the transaction, call propose_entry — do not
    describe the entry in prose instead. Never invent an account id.
  PROMPT

  def perform(llm_chat_id, content)
    llm_chat = Llm::Chat.find(llm_chat_id)

    llm_chat
      .with_instructions(INSTRUCTIONS, replace: true)
      .with_tools(ListAccounts.new(llm_chat.workspace), ProposeEntry.new(llm_chat.workspace))
      .ask(content) do |chunk|
        if chunk.content && !chunk.content.empty?
          llm_message = llm_chat.llm_messages.last
          llm_message.broadcast_append_chunk(chunk.content)
        end
      end
  ensure
    llm_chat&.broadcast_remove_to "llm_chat_#{llm_chat_id}", target: "llm_chat_#{llm_chat_id}_pending"
  end
end
