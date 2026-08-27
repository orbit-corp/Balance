class Llm::Chat < ApplicationRecord
  self.table_name = "llm_chats"

  CONTEXT_WINDOW_TOKENS = 200_000
  COMPACTION_THRESHOLD = 0.7
  TAIL_BUDGET_TOKENS = (CONTEXT_WINDOW_TOKENS * 0.6).to_i
  PRUNE_PROTECT_TOKENS = 40_000
  CHARS_PER_TOKEN = 4
  MESSAGE_OVERHEAD_TOKENS = 5

  belongs_to :workspace
  has_many :proposals, foreign_key: :llm_chat_id, dependent: :destroy
  has_many :llm_activities, class_name: "Llm::Activity", foreign_key: :llm_chat_id, dependent: :destroy
  has_many :llm_turns, class_name: "Llm::Turn", foreign_key: :llm_chat_id, dependent: :destroy
  has_many :llm_transaction_sessions, class_name: "Llm::TransactionSession", foreign_key: :llm_chat_id, dependent: :destroy

  attr_accessor :active_turn

  acts_as_chat messages: :llm_messages, message_class: "Llm::Message", messages_foreign_key: :llm_chat_id, model: :llm_model, model_class: "Llm::Model"

  def to_param
    uuid
  end

  def self.estimated_tokens(text)
    (text.to_s.length.to_f / CHARS_PER_TOKEN).ceil + MESSAGE_OVERHEAD_TOKENS
  end

  def timeline
    items = []
    visible_messages.each { |message| items << { type: :message, record: message, at: message.created_at } }
    llm_activities.each { |activity| items << { type: :activity, record: activity, at: activity.created_at } }
    persisted_tool_calls.each { |tool_call| items << { type: :tool_call, record: tool_call, at: tool_call.created_at } }
    proposals.each { |proposal| items << { type: :proposal, record: proposal, at: proposal.created_at } }
    llm_turns.unfinished.each { |turn| items << { type: :turn, record: turn, at: turn.created_at } }
    items.sort_by { |item| item[:at] }
  end

  def visible_messages
    llm_messages.where(role: %w[user assistant]).where.not(content: [ nil, "" ]).order(:created_at, :id)
  end

  def awaiting_response?
    llm_turns.unfinished.exists?
  end

  def persisted_tool_calls
    scope = Llm::ToolCall.joins(:llm_message)
      .where(llm_messages: { llm_chat_id: id })

    visible_tools = %w[list_accounts list_journal_entries get_balance_summary check_proposal_status]
    proposal_tools = scope.where(name: %w[propose_entry propose_account propose_reversal])
      .where(llm_message_id: proposals.where.not(llm_message_id: nil).select(:llm_message_id))

    scope.where(name: visible_tools).or(proposal_tools)
      .order(:created_at, :id)
  end

  def latest_proposal(type = nil)
    scope = proposals.proposed
    scope = scope.by_type(type) if type
    scope.order(version: :desc).first
  end

  def start_turn(content)
    create_turn(role: "user", content: content)
  end

  def resume_turn(content, transaction_session:)
    create_turn(role: "system", content: content, transaction_session: transaction_session)
  end

  def create_turn(role:, content:, transaction_session: nil)
    transaction do
      message = llm_messages.create!(role: role, content: content)
      turn = llm_turns.create!(user_message: message, llm_transaction_session: transaction_session)
      LlmChatResponseJob.perform_later(id, turn.id)
      message
    end
  end

  def active_context_messages
    return llm_messages.to_a unless active_turn

    ids = active_turn.context_message_ids.map(&:to_i)
    ids << active_turn.user_message_id
    current_ids = active_turn.output_messages.pluck(:id)
    llm_messages.where(id: (ids + current_ids).uniq).order(:created_at, :id).to_a
  end

  def derive_title_from(prompt)
    truncated = prompt.to_s.squish.delete_suffix(".").truncate(60, separator: " ", omission: "…")
    self.title = truncated.present? ? truncated[0].upcase + truncated[1..] : "New chat"
  end

  def needs_compaction?
    unsummarized.sum { |message| self.class.estimated_tokens(message.content) } > (CONTEXT_WINDOW_TOKENS * COMPACTION_THRESHOLD)
  end

  def current_summary
    unsummarized.where(role: "system").order(:id).to_a.drop(1).last
  end

  def foldable_head
    dialogue = unsummarized.where.not(role: "system").order(:created_at, :id).to_a
    dialogue - tail_fitting(dialogue)
  end

  private

  # RubyLLM replaces every system message with the new instructions on each
  # agent setup, which would destroy the compaction summary.
  def replace_persisted_system_instructions(instructions)
    current = unsummarized.where(role: "system").order(:id).first

    if current
      current.update!(content: instructions) if current.content != instructions
    else
      llm_messages.create!(role: "system", content: instructions)
    end
  end

  def order_messages_for_llm(messages)
    active = messages.reject(&:summarized_at)
    system_messages, dialogue = active.partition { |message| message.role.to_s == "system" }
    if active_turn && system_messages.any?
      base_system_id = system_messages.first.id
      allowed_system_ids = active_turn.context_message_ids.map(&:to_i) + [ active_turn.user_message_id, base_system_id ]
      system_messages.select! { |message| allowed_system_ids.include?(message.id) }
    end
    dialogue = if active_turn
      allowed_ids = active_context_messages.map(&:id)
      dialogue.select { |message| allowed_ids.include?(message.id) }
    else
      Llm::ActiveTransactionContext.new(dialogue, currency_code: workspace.currency_code).messages
    end
    return dialogue if system_messages.empty?

    merged = system_messages.first.dup
    merged.content = system_messages.map(&:content).join("\n\n")
    [ merged ] + dialogue
  end

  def unsummarized
    llm_messages.where(summarized_at: nil)
  end

  def tail_fitting(dialogue)
    kept = []
    budget = TAIL_BUDGET_TOKENS

    dialogue.reverse_each do |message|
      tokens = self.class.estimated_tokens(message.content)
      break if tokens > budget

      kept.unshift(message)
      budget -= tokens
    end

    kept.drop_while { |message| message.role.to_s != "user" }
  end
end
