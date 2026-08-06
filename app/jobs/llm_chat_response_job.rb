class LlmChatResponseJob < ApplicationJob
  PROPOSAL_PARTIALS = Llm::MessagesHelper::PROPOSAL_PARTIALS

  INSTRUCTIONS = <<~PROMPT
    You help record personal financial transactions into a double-entry ledger.

    Use list_accounts to see what accounts exist before answering.

    To record a transaction, call propose_entry with exactly one of these shapes:
    money_spent, money_received, lent_out, loan_repaid_to_user, borrowed_cash,
    bought_on_credit, debt_paid_off, bank_fee, opening_balance, money_in_unknown_source,
    money_out_unknown_reason. Every shape fully determines both accounts.

    If you can't tell which account a shape's counterparty-driven side belongs to (for
    example gift vs. loan), or you don't have a counterparty name, still call
    propose_entry and set undecided: true rather than asking a clarifying question — the
    proposal card is where the user resolves that, not the chat.

    After calling propose_entry, acknowledge in one short sentence and stop. The card
    already shows the entry — do not describe it again in prose. Never invent an account id.
  PROMPT

  def perform(llm_chat_id, content)
    llm_chat = Llm::Chat.find(llm_chat_id)
    current_tool_call = nil

    llm_chat
      .with_instructions(INSTRUCTIONS, replace: true)
      .with_tools(ListAccounts.new(llm_chat.workspace), ProposeEntry.new(llm_chat.workspace))

    llm_chat.on_tool_call do |tool_call|
      cleanup_empty_assistant_messages(llm_chat)
      current_tool_call = tool_call
      broadcast_tool_running(llm_chat, tool_call)
    end

    llm_chat.on_tool_result do |result|
      if result.is_a?(Hash) && result[:proposal]
        create_and_broadcast_proposal(llm_chat, current_tool_call, result)
      else
        broadcast_tool_completed(llm_chat, current_tool_call, result)
      end
      current_tool_call = nil
    end

    llm_chat.ask(content) do |chunk|
      if chunk.content && !chunk.content.empty?
        llm_message = llm_chat.llm_messages.last
        llm_message.broadcast_append_chunk(chunk.content)
      end
    end

    cleanup_empty_assistant_messages(llm_chat)
  ensure
    llm_chat&.broadcast_remove_to "llm_chat_#{llm_chat_id}", target: "llm_chat_#{llm_chat_id}_pending"
  end

  private

  # An assistant placeholder is created blank before the model's response is known, so a
  # tool-call-only round leaves it empty — remove it rather than showing a dead bubble.
  def cleanup_empty_assistant_messages(llm_chat)
    llm_chat.llm_messages.where(role: "assistant")
      .where("content IS NULL OR TRIM(content) = ''")
      .find_each { |message| message.broadcast_remove_to "llm_chat_#{llm_chat.id}", target: "llm_message_#{message.id}" }
  end

  def broadcast_tool_running(llm_chat, tool_call)
    Turbo::StreamsChannel.broadcast_append_to "llm_chat_#{llm_chat.id}",
      target: "llm_messages",
      partial: "llm/messages/tool_execution",
      locals: { tool_call_id: tool_call.id, tool_name: tool_call.name, state: :running }
  end

  def broadcast_tool_completed(llm_chat, tool_call, result)
    Turbo::StreamsChannel.broadcast_replace_to "llm_chat_#{llm_chat.id}",
      target: "tool_call_#{tool_call&.id}",
      partial: "llm/messages/tool_execution",
      locals: { tool_call_id: tool_call&.id, tool_name: tool_call&.name, state: :completed, output: result }
  end

  def create_and_broadcast_proposal(llm_chat, tool_call, result)
    proposal_type = result[:proposed_action]

    existing = llm_chat.proposals.proposed.by_type(proposal_type)
    old_ids = existing.pluck(:id)
    version = (llm_chat.proposals.by_type(proposal_type).maximum(:version) || 0) + 1
    existing.update_all(status: "superseded")

    proposal = llm_chat.proposals.create!(
      workspace: llm_chat.workspace,
      proposal_type: proposal_type,
      version: version,
      data: result[:entry_data]
    )

    old_ids.each do |old_id|
      Turbo::StreamsChannel.broadcast_remove_to "llm_chat_#{llm_chat.id}", target: "proposal_#{old_id}"
    end

    partial = PROPOSAL_PARTIALS[proposal_type] || "llm/messages/proposals/#{proposal_type}"
    Turbo::StreamsChannel.broadcast_replace_to "llm_chat_#{llm_chat.id}",
      target: "tool_call_#{tool_call&.id}",
      partial: partial,
      locals: { proposal: proposal }
  end
end
