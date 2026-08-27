class Llm::ChatTurn
  TIMEOUT_SECONDS = 60
  MAX_PROVIDER_ATTEMPTS = 3

  AFFIRMATIVE_PATTERN = ProposeReversal::AFFIRMATIVE_PATTERN
  REVERSAL_DIRECTIVE = "CONFIRMED REVERSAL"

  class TurnTimeout < StandardError; end

  def initialize(chat:, agent: nil, compactor: nil)
    @chat = chat
    @agent = agent
    @compactor = compactor
    @running_tool_calls = []
    @broadcaster = Llm::ChatBroadcaster.new(chat)
    @publisher = Llm::ProposalPublisher.new(chat: chat, broadcaster: @broadcaster)
  end

  def call
    attempts = 0
    @turn_user_id = @chat.llm_messages.where(role: "user").order(id: :desc).pick(:id)
    @proposal_published = false
    @grounding_failure = false

    if (question = active_transaction_context.clarification_question)
      report_failure(question)
      return
    end

    begin
      attempts += 1
      Timeout.timeout(TIMEOUT_SECONDS, TurnTimeout) do
        prepare_confirmed_reversal_directive
        agent = @agent || LedgerAgent.new(chat: @chat)
        agent.before_tool_call { |tool_call| start_tool_call(tool_call) }
        agent.after_tool_result { |result| finish_tool_call(result) }

        result = run_turn(agent)
        unless result.is_a?(RubyLLM::Tool::Halt)
          retry_silent_turn(agent)
          retry_stalled_reversal(agent)
        end
        retry_unfinished_transaction(agent)
        enforce_grounded_outcome
      end
    rescue RubyLLM::ContextLengthExceededError
      raise unless compact_context(force: true)

      retry
    rescue RubyLLM::Error
      if attempts < MAX_PROVIDER_ATTEMPTS
        sleep 1
        retry
      end
      raise
    end

    @broadcaster.remove_empty_assistant_messages
  rescue TurnTimeout
    report_failure("I couldn't finish this request in time. Please try again with a shorter, more specific transaction description.")
  rescue RubyLLM::Error
    report_failure("The accounting assistant is temporarily unavailable. Please try again.")
  rescue Faraday::ConnectionFailed
    report_failure("The accounting assistant is temporarily unavailable. Please try again.")
  rescue StandardError => e
    p An error occured
    Rails.logger.error("ChatTurn failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(10).to_a.join("\n")}")
    report_failure("I hit a problem while answering. Please try again.")
  ensure
    @running_tool_calls.each { |tool_call| @broadcaster.remove_tool_call(tool_call) }
    @broadcaster.remove_pending
    @broadcaster.remove_empty_assistant_messages
  end

  private

  def run_turn(agent)
    @reversal_attempted_this_turn = false
    @broadcaster.pending
    compact_context

    agent.complete do |chunk|
      @broadcaster.append_assistant_chunk(chunk.content) if chunk.content.present?
    end
  end

  def compact_context(force: false)
    return false unless force || @chat.needs_compaction?

    @broadcaster.compacting
    (@compactor || Llm::ChatCompactor.new(@chat)).call
  end

  def retry_silent_turn(agent)
    return unless last_assistant_message&.content.blank?

    run_turn(agent)

    return unless last_assistant_message&.content.blank?

    report_failure("I wasn't able to respond. Could you rephrase that?")
  end

  # The model sometimes repeats its confirmation question instead of calling
  # propose_reversal after the user approves. Retry once with an explicit
  # directive once a stalled reversal loop is detected.
  def retry_stalled_reversal(agent)
    return unless stalled_reversal_question?

    entry = reversal_target
    last_user = @chat.llm_messages.where(role: "user").order(:id).last
    return unless entry && reversal_directive_missing?(entry, last_user)

    @chat.with_instructions(reversal_directive(entry, last_user), replace: false)
    agent.complete do |chunk|
      @broadcaster.append_assistant_chunk(chunk.content) if chunk.content.present?
    end
  end

  def stalled_reversal_question?
    return false if @reversal_attempted_this_turn

    last_user = @chat.llm_messages.where(role: "user").order(:id).last
    return false unless confirmed_reversal_question_before(last_user)

    last = @chat.llm_messages.order(:id).last
    return false unless last&.role.to_s == "assistant"
    return false unless last.content.to_s.match?(ProposeReversal::REVERSAL_QUESTION_PATTERN)

    last_user&.content.to_s.match?(AFFIRMATIVE_PATTERN)
  end

  def prepare_confirmed_reversal_directive
    last_user = @chat.llm_messages.where(role: "user").order(:id).last
    question = confirmed_reversal_question_before(last_user)
    return unless question

    entry = reversal_target(question.content)
    return unless entry && reversal_directive_missing?(entry, last_user)

    @chat.llm_messages.create!(role: "system", content: reversal_directive(entry, last_user))
  end

  def confirmed_reversal_question_before(user_message)
    return unless user_message&.content.to_s.match?(AFFIRMATIVE_PATTERN)

    message = @chat.llm_messages.where(role: "assistant")
      .where("id < ?", user_message.id)
      .where.not(content: [ nil, "" ])
      .order(:id)
      .last
    message if message&.content.to_s.match?(ProposeReversal::REVERSAL_QUESTION_PATTERN)
  end

  def reversal_target(question = @chat.llm_messages.order(:id).last&.content.to_s)
    id = question[/\bJE\s*(\d+)\b/i, 1]&.to_i
    scope = @chat.workspace.journal_entries
    (id && scope.find_by(id: id)) || scope.order(entry_date: :desc, id: :desc).first
  end

  def reversal_directive_missing?(entry, user_message)
    !@chat.llm_messages.where(role: "system")
      .where("content LIKE ?", "%#{REVERSAL_DIRECTIVE} for journal entry #{entry.id} after user message #{user_message.id}%")
      .exists?
  end

  def reversal_directive(entry, user_message)
    "#{REVERSAL_DIRECTIVE} for journal entry #{entry.id} after user message #{user_message.id}: the user approved its reversal. " \
      "The entry is posted. Call propose_reversal with entry_id #{entry.id} now; do not check proposal status or ask again."
  end

  def last_assistant_message
    @chat.llm_messages.where(role: "assistant").order(:id).last
  end

  def start_tool_call(tool_call)
    @reversal_attempted_this_turn ||= tool_call.name == "propose_reversal"

    @broadcaster.remove_pending
    publish_understanding(tool_call)
    @current_tool_call = tool_call
    @running_tool_calls << tool_call
    persisted_tool_call(tool_call)&.update!(trace_status: "running")
    @broadcaster.tool_running(tool_call)
  end

  def publish_understanding(tool_call)
    return if @understanding_published || @turn_user_id.blank?
    if @broadcaster.response_started?
      @understanding_published = true
      return
    end

    persisted_tool_call = persisted_tool_call(tool_call)

    context = active_transaction_context
    source_messages = context.transaction? ? context.messages : @chat.llm_messages.where(id: @turn_user_id)
    facts = source_messages
      .select { |message| message.role.to_s == "user" }
      .map { |message| message.content.to_s.squish.delete_suffix(".") }
      .reject(&:blank?)
      .join(" — ")
      .truncate(120, separator: " ", omission: "…")
    content = if context.transaction? && facts.present?
      "I understand the transaction as: #{facts}. I’ll verify the accounts and prepare the entry."
    else
      tool_progress_statement(tool_call.name)
    end

    activity = @chat.llm_activities.find_or_initialize_by(
      turn_user_message_id: @turn_user_id,
      kind: "understanding"
    )
    created = activity.new_record?
    activity.content = content
    activity.created_at ||= (persisted_tool_call&.created_at || Time.current) - 1.microsecond
    activity.save!
    @broadcaster.activity(activity) if created
    @understanding_published = true
  end

  def tool_progress_statement(tool_name)
    {
      "get_balance_summary" => "I understand the request. I’ll calculate the posted balances.",
      "list_journal_entries" => "I understand the request. I’ll check the posted journal entries.",
      "check_proposal_status" => "I understand the request. I’ll check whether the proposal was recorded.",
      "propose_reversal" => "I understand the request. I’ll prepare the confirmed reversal for review."
    }.fetch(tool_name, "I understand the request. I’ll prepare the appropriate accounting result.")
  end

  def finish_tool_call(result)
    payload = tool_payload(result)

    if tool_failure?(payload)
      @grounding_failure ||= payload[:grounding_error]
      persist_tool_result(@current_tool_call, payload, status: "failed")
      @broadcaster.tool_failed(@current_tool_call, payload)
      @running_tool_calls.delete(@current_tool_call)
      @current_tool_call = nil
      @broadcaster.working
      return payload
    end

    if proposal?(payload)
      persist_tool_result(@current_tool_call, payload, status: "completed")
      @publisher.publish(tool_call: @current_tool_call, result: payload)
      @proposal_published = true
    else
      persist_tool_result(@current_tool_call, payload, status: "completed")
      @broadcaster.tool_completed(@current_tool_call, payload)
      @broadcaster.working
    end

    @running_tool_calls.delete(@current_tool_call)
    @current_tool_call = nil
    payload
  end

  def tool_payload(result)
    result.is_a?(RubyLLM::Tool::Halt) ? result.content : result
  end

  def persisted_tool_call(tool_call)
    Llm::ToolCall.find_by(tool_call_id: tool_call.id)
  end

  def persist_tool_result(tool_call, payload, status:)
    persisted_tool_call(tool_call)&.update!(trace_status: status, trace_output: payload)
  end

  def tool_failure?(result)
    result.is_a?(Hash) && result.key?(:error)
  end

  def proposal?(result)
    result.is_a?(Hash) && result[:proposal]
  end

  def report_failure(message)
    @chat.llm_messages.create!(role: "assistant", content: message)
  end

  def retry_unfinished_transaction(agent)
    return if @proposal_published

    context = active_transaction_context
    return unless context.transaction?

    response = turn_assistant_messages.where.not(content: [ nil, "" ]).order(:id).last&.content.to_s.strip
    return if grounded_refusal?(response, context)
    return if grounded_clarification?(response, context) && !question_already_answered?(response, context)

    clear_turn_assistant_messages
    account_result = persist_account_lookup
    directive = nil
    2.times do
      directive = recovery_directive(account_result)
      run_turn(agent)
      directive.destroy!
      directive = nil
      break if @proposal_published

      response = turn_assistant_messages.where.not(content: [ nil, "" ]).order(:id).last&.content.to_s.strip
      break if grounded_clarification?(response, context) && !question_already_answered?(response, context)

      clear_turn_assistant_messages
    end
  ensure
    directive&.destroy!
  end

  def enforce_grounded_outcome
    return if @proposal_published

    context = active_transaction_context
    return unless @grounding_failure || context.transaction?

    response = turn_assistant_messages.where.not(content: [ nil, "" ]).order(:id).last&.content.to_s.strip
    return if grounded_clarification?(response, context) || grounded_refusal?(response, context)

    clear_turn_assistant_messages
    report_failure("I couldn't verify an entry against your latest transaction, so I did not create a proposal. Please restate the amount, date, and payment source in one message.")
  end

  def grounded_clarification?(response, context)
    response.present? && response.end_with?("?") && response.count("?") == 1 &&
      !response.match?(/(?:\A|\n)\s*(?:[-*]|\d+[.)])\s+/) &&
      context.response_amounts_grounded?(response)
  end

  def grounded_refusal?(response, context)
    response.match?(/\b(?:can't|cannot|won't|will not) help\b/i) && context.response_amounts_grounded?(response)
  end

  def question_already_answered?(response, context)
    asks_for_payment_source = response.match?(/\bhow\b.*\b(?:pay|paid|receive|received)\b/i)
    payment_source_known = context.user_text.match?(/\b(?:cash|bank|transfer|card|credit|loan|receivable|payable)\b/i)
    fee_route_settled = response.match?(/\b(?:deducted separately|included in)\b/i) &&
      context.user_text.match?(/\bfee\b.*\b(?:also )?charged\b/i)

    (asks_for_payment_source && payment_source_known) || fee_route_settled
  end

  def clear_turn_assistant_messages
    turn_assistant_messages.find_each do |message|
      message.broadcast_remove_to("llm_chat_#{@chat.id}", target: "llm_message_#{message.id}")
      message.update_column(:content, "") if message.content.present?
    end
  end

  def persist_account_lookup
    result = ListAccounts.new(@chat.workspace).execute
    call_message = @chat.llm_messages.create!(role: "assistant", content: "".encode(Encoding::UTF_8))
    tool_call = call_message.llm_tool_calls.create!(
      tool_call_id: "recovery_list_accounts_#{SecureRandom.hex(12)}",
      name: "list_accounts",
      arguments: {}
    )
    tool_call.update!(trace_status: "completed", trace_output: result)
    @chat.llm_messages.create!(role: "tool", content: result.to_json, llm_tool_call_id: tool_call.id)
    @broadcaster.tool_append_completed(tool_call, result)
    result
  end

  def recovery_directive(account_result)
    @chat.llm_messages.create!(
      role: "system",
      content: "ACTIVE TRANSACTION RECOVERY: The user's current transaction is complete enough to process. " \
        "The mandatory list_accounts lookup has already completed with this authoritative result: " \
        "#{account_result.to_json}. Call propose_entry or propose_account now. " \
        "Do not narrate intended actions or reuse any older transaction."
    )
  end

  def turn_assistant_messages
    @chat.llm_messages.where(role: "assistant").where("id > ?", @turn_user_id)
  end

  def active_transaction_context
    Llm::ActiveTransactionContext.new(
      @chat.llm_messages.to_a,
      currency_code: @chat.workspace.currency_code
    )
  end
end
