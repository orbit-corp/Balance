class Llm::TurnClassifier
  class InvalidClassification < StandardError; end

  TOOL_ROUTES = {
    "conversation" => [],
    "transaction" => %w[list_accounts propose_account propose_entry],
    "balance" => %w[get_balance_summary],
    "journal_entries" => %w[list_journal_entries],
    "account_setup" => %w[list_accounts propose_account],
    "proposal_status" => %w[check_proposal_status],
    "proposal_confirmation" => %w[confirm_proposal],
    "reversal" => %w[list_journal_entries],
    "reversal_confirmation" => %w[propose_reversal],
    "refusal" => []
  }.freeze

  def initialize(chat:, turn:, agent: nil)
    @chat = chat
    @turn = turn
    @agent = agent
  end

  def call
    response = agent.ask(classification_prompt)
    result = structured_result(response)
    intent = result.fetch("intent")
    relationship = result.fetch("relationship")
    @context_session = related_session(intent, relationship)
    transaction = normalize_transaction(intent, relationship, result.fetch("transaction"))
    result["transaction"] = transaction
    tools = intent == "transaction" && !transaction.fetch("ready") ? [] : TOOL_ROUTES.fetch(intent)
    session = update_transaction_session(intent, relationship, transaction)
    context_ids = context_message_ids(relationship, session || @context_session)

    @turn.update!(
      intent: intent,
      relationship: relationship,
      llm_transaction_session: session || @context_session,
      allowed_tools: tools,
      classification: result,
      context_message_ids: context_ids
    )
    @turn
  rescue KeyError, NoMethodError, TypeError => error
    raise InvalidClassification, "Invalid turn classification: #{error.message}"
  end

  private

  def agent
    @agent || TurnClassifierAgent.new(
      model: @chat.llm_model&.model_id || RubyLLM.config.default_model,
      workspace_type: @chat.workspace.workspace_type,
      currency_code: @chat.workspace.currency_code,
      today: Date.current.iso8601,
      pending_transaction: session_payload(pending_session),
      recent_transaction: session_payload(recent_transaction_session)
    )
  end

  def classification_prompt
    <<~PROMPT
      Previous assistant message: #{previous_assistant&.content.presence || "none"}
      Latest user message: #{@turn.user_message.content}
    PROMPT
  end

  def structured_result(response)
    content = response.content
    raise TypeError, "expected an object" unless content.respond_to?(:to_h)

    content.to_h.deep_stringify_keys
  end

  def normalize_transaction(intent, relationship, transaction)
    carries_transaction = intent == "transaction" || (relationship == "continuation" && @context_session)
    return transaction unless carries_transaction

    supplied = transaction.reject { |_key, value| value.blank? }
    normalized = @context_session&.facts.to_h.merge(supplied)
    normalized["date"] = Date.current.iso8601 if normalized["date"].blank?
    reported_missing = Array(normalized["missing_facts"])
    if normalized["summary"].blank? && ((reported_missing & %w[event description]).empty? || grounded_transaction?)
      normalized["summary"] = source_messages.first&.content.to_s.squish
    end
    normalized["amount"] = grounded_amount if grounded_amount
    normalized["payment_source"] = grounded_payment_source.to_s if supplied["payment_source"].blank? && grounded_payment_source

    missing = Array(normalized["missing_facts"]).select { |fact| %w[event description amount date].include?(fact) }
    missing.delete("amount") if normalized["amount"].present?
    missing.delete("date") if normalized["date"].present?
    missing -= %w[event description] if normalized["summary"].present?
    missing << "amount" if normalized["amount"].blank?
    missing << "description" if normalized["summary"].blank? && (missing & %w[event description]).empty?
    missing.uniq!
    normalized["missing_facts"] = missing.sort_by do |fact|
      %w[event description amount date].index(fact) || 99
    end
    normalized["ready"] = normalized["missing_facts"].empty?
    normalized
  end

  def source_messages
    @source_messages ||= begin
      ids = @context_session&.source_message_ids.to_a.map(&:to_i)
      ids << @turn.user_message_id
      @chat.llm_messages.where(id: ids.uniq).order(:id).to_a
    end
  end

  def grounded_amount
    context = Llm::ActiveTransactionContext.new(
      source_messages,
      currency_code: @chat.workspace.currency_code
    )
    amount_kobo = context.primary_amount_kobo
    return unless amount_kobo

    amount = BigDecimal(amount_kobo.to_s) / 100
    number = amount.frac.zero? ? amount.to_i.to_s : amount.to_s("F")
    "#{number} #{@chat.workspace.currency_code}"
  end

  def grounded_payment_source
    source_messages.reverse_each do |message|
      source = payment_source_in(message.content.to_s)
      return source if source
    end
    nil
  end

  def grounded_transaction?
    Llm::ActiveTransactionContext.new(
      source_messages,
      currency_code: @chat.workspace.currency_code
    ).transaction?
  end

  def payment_source_in(text)
    return "cash" if text.match?(/\bcash\b/i)
    return "bank transfer" if text.match?(/\b(?:bank\s+)?transfer(?:red)?\b/i)
    return "card" if text.match?(/\bcard\b/i)
    return "digital wallet" if text.match?(/\b(?:digital\s+)?wallet\b/i)
    return "cheque" if text.match?(/\b(?:cheque|check)\b/i)
    return "savings" if text.match?(/\bsavings\b/i)
    return "checking" if text.match?(/\bchecking\b/i)
    return "bank account" if text.match?(/\bbank(?:\s+account)?\b/i)
    "credit" if text.match?(/\bon\s+credit\b/i)
  end

  def previous_assistant
    @previous_assistant ||= @chat.llm_messages
      .where(role: "assistant")
      .where("id < ?", @turn.user_message_id)
      .where.not(content: [ nil, "" ])
      .order(:id)
      .last
  end

  def pending_session
    @pending_session ||= @chat.llm_transaction_sessions.pending.order(:id).last
  end

  def recent_transaction_session
    @recent_transaction_session ||= @chat.llm_transaction_sessions
      .where.not(status: "abandoned")
      .order(:id)
      .last
  end

  def related_session(intent, relationship)
    return unless relationship == "continuation"
    return pending_session if pending_session
    recent_transaction_session if %w[transaction account_setup proposal_status proposal_confirmation conversation].include?(intent)
  end

  def session_payload(session)
    return unless session

    {
      status: session.status,
      facts: session.facts,
      last_question: session.last_question_message&.content,
      latest_proposal: latest_proposal_payload(session)
    }.to_json
  end

  def latest_proposal_payload(session)
    proposal = latest_proposal_for(session)
    return unless proposal

    {
      type: proposal.proposal_type,
      status: proposal.status,
      data: proposal.data
    }
  end

  def latest_proposal_for(session)
    return unless session

    @chat.proposals
      .joins(:llm_message)
      .where(llm_messages: { llm_turn_id: session.llm_turns.select(:id) })
      .order(id: :desc)
      .first
  end

  def update_transaction_session(intent, relationship, transaction)
    unless intent == "transaction"
      pending_session&.update!(status: "paused")
      return
    end

    session = relationship == "continuation" ? @context_session : nil
    if session.nil?
      pending_session&.update!(status: "abandoned")
      session = @chat.llm_transaction_sessions.create!
    end

    session.merge_facts!(transaction)
    session.update!(
      status: "open",
      source_message_ids: transaction_source_message_ids(session)
    )
    session
  end

  def context_message_ids(relationship, session)
    unless relationship == "continuation" && session
      ids = [ @turn.user_message_id ]
      ids.unshift(previous_assistant.id) if relationship == "continuation" && previous_assistant
      return ids
    end

    ids = session.source_message_ids.map(&:to_i)
    ids << session.last_question_message_id if session.last_question_message_id
    ids << latest_proposal_for(session)&.llm_message_id
    ids << previous_assistant.id if previous_assistant
    ids.compact.uniq
  end

  def transaction_source_message_ids(session)
    ids = session.source_message_ids.map(&:to_i)
    ids << @turn.user_message_id if @turn.user_message.role == "user"
    ids.uniq
  end
end
