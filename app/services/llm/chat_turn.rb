class Llm::ChatTurn
  TIMEOUT_SECONDS = 180
  MAX_PROVIDER_ATTEMPTS = 3

  class TurnTimeout < StandardError; end
  class InvalidToolCall < StandardError; end

  def initialize(chat:, turn: nil, agent: nil, compactor: nil)
    @chat = chat
    @turn = turn || chat.llm_turns.where(status: "queued").order(:id).first
    @agent = agent
    @compactor = compactor
    @running_tool_calls = []
    @broadcaster = Llm::ChatBroadcaster.new(chat, turn: @turn)
    @publisher = Llm::ProposalPublisher.new(chat: chat, broadcaster: @broadcaster)
  end

  def call
    return call_legacy if @turn.nil? && @agent
    return unless @turn
    return if @turn.status.in?(%w[completed failed])

    @chat.active_turn = @turn
    Llm::Current.turn = @turn
    @turn.update!(status: "classifying", started_at: Time.current)
    @broadcaster.turn_status("Thinking…")

    Timeout.timeout(TIMEOUT_SECONDS, TurnTimeout) do
      with_provider_retries { classify_turn }
      publish_progress
      run_model
      ensure_final_response
      update_transaction_session
    end

    @turn.finish!
    @broadcaster.remove_turn_status
  rescue TurnTimeout
    fail_turn("I couldn't finish this request in time. Please try again.")
  rescue RubyLLM::Error, Faraday::ConnectionFailed
    fail_turn("The accounting assistant is temporarily unavailable. Please try again.")
  rescue StandardError => e
    p e.message
    Rails.logger.error("ChatTurn failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(10).to_a.join("\n")}")
    fail_turn("I hit a problem while answering. Please try again.")
  ensure
    @running_tool_calls.each { |tool_call| @broadcaster.remove_tool_call(tool_call) }
    @broadcaster.remove_empty_assistant_messages
    @chat.active_turn = nil
    Llm::Current.reset
  end

  private

  def call_legacy
    @turn_user_id = @chat.llm_messages.where(role: "user").order(:id).pick(:id) || 0
    @broadcaster.pending

    Timeout.timeout(TIMEOUT_SECONDS, TurnTimeout) do
      prepare_legacy_reversal_directive
      @agent.before_tool_call { |tool_call| start_tool_call(tool_call) }
      @agent.after_tool_result { |result| finish_tool_call(result) }
      compact_context
      result = with_provider_retries { @agent.complete { |chunk| @broadcaster.append_assistant_chunk(chunk.content) if chunk.content.present? } }

      unless result.is_a?(RubyLLM::Tool::Halt)
        retry_legacy_silent_completion
      end
    end
  rescue TurnTimeout
    legacy_failure("I couldn't finish this request in time. Please try again.")
  rescue RubyLLM::Error, Faraday::ConnectionFailed
    legacy_failure("The accounting assistant is temporarily unavailable. Please try again.")
  rescue StandardError => error
    Rails.logger.error("Legacy ChatTurn failed: #{error.class}: #{error.message}")
    legacy_failure("I hit a problem while answering. Please try again.")
  ensure
    @running_tool_calls.each { |tool_call| @broadcaster.remove_tool_call(tool_call) }
    @broadcaster.remove_pending
    @broadcaster.remove_empty_assistant_messages
  end

  def retry_legacy_silent_completion
    return if legacy_last_assistant&.content.present?

    with_provider_retries do
      @agent.complete { |chunk| @broadcaster.append_assistant_chunk(chunk.content) if chunk.content.present? }
    end
    legacy_failure("I wasn't able to respond. Could you rephrase that?") if legacy_last_assistant&.content.blank?
  end

  def legacy_last_assistant
    @chat.llm_messages.where(role: "assistant").where("id > ?", @turn_user_id).order(:id).last
  end

  def legacy_failure(content)
    @chat.llm_messages.create!(role: "assistant", content: content, response_turn: @turn)
  end

  def prepare_legacy_reversal_directive
    user = @chat.llm_messages.where(role: "user").order(:id).last
    return unless user&.content.to_s.match?(ProposeReversal::AFFIRMATIVE_PATTERN)

    question = @chat.llm_messages.where(role: "assistant")
      .where("id < ?", user.id)
      .where.not(content: [ nil, "" ])
      .order(:id)
      .last
    return unless question&.content.to_s.match?(ProposeReversal::REVERSAL_QUESTION_PATTERN)

    entry_id = question.content[/\bJE\s*(\d+)\b/i, 1]&.to_i
    entry = (entry_id && @chat.workspace.journal_entries.find_by(id: entry_id)) ||
      @chat.workspace.journal_entries.order(entry_date: :desc, id: :desc).first
    return unless entry

    content = "CONFIRMED REVERSAL for journal entry #{entry.id} after user message #{user.id}: " \
      "the user approved its reversal. Call propose_reversal with entry_id #{entry.id} now; do not ask again."
    return if @chat.llm_messages.where(role: "system", content: content).exists?

    @chat.llm_messages.create!(role: "system", content: content)
  end

  def with_provider_retries
    attempts = 0

    begin
      attempts += 1
      yield
    rescue RubyLLM::ContextLengthExceededError
      raise unless compact_context(force: true)

      retry
    rescue RubyLLM::Error
      raise if attempts >= MAX_PROVIDER_ATTEMPTS

      sleep 1
      retry
    end
  end

  def classify_turn
    Llm::TurnClassifier.new(chat: @chat, turn: @turn).call
    @chat.active_turn = @turn.reload
  end

  def publish_progress
    content = @turn.classification["progress_message"].to_s.squish
    return if content.blank? || @turn.allowed_tools.blank? || completed_claim?(content)

    activity = @chat.llm_activities.find_or_create_by!(
      turn_user_message_id: @turn.user_message_id,
      kind: "understanding"
    ) { |record| record.content = content }
    @broadcaster.activity(activity)
    @turn.update!(status: "working")
    @broadcaster.turn_status("Working…")
  end

  def completed_claim?(content)
    content.match?(/\b(recorded|posted|created|prepared|completed)\b/i)
  end

  def run_model
    @turn.update!(status: "responding") unless @turn.status == "working"
    agent = configured_agent
    agent.before_tool_call { |tool_call| start_tool_call(tool_call) }
    agent.after_tool_result { |result| finish_tool_call(result) }

    run_completion(agent)
    run_completion(agent) if no_visible_response_or_tool?
  end

  def configured_agent
    agent = @agent || LedgerAgent.new(chat: @chat)
    tools = Llm::Toolset.for(@chat, @turn.allowed_tools)
    agent.with_tools(*tools, replace: true)
    @chat.with_runtime_instructions(route_instructions, append: true)
    agent
  end

  def route_instructions
    facts = @turn.classification["transaction"] || {}

    <<~TEXT
      CURRENT TURN ROUTE (authoritative):
      - Intent: #{@turn.intent}
      - Relationship: #{@turn.relationship}
      - Allowed tools: #{@turn.allowed_tools.presence&.join(", ") || "none"}
      - Resolved transaction state: #{facts.to_json}

      Answer only the current user turn. Do not continue a paused transaction unless the route says continuation.
      The scoped messages and resolved transaction state are available conversation history. Use them and never claim that supplied earlier details are unavailable.
      Never call a tool outside the allowed list. If no tools are allowed, respond directly.
      For an incomplete transaction, ask exactly one short question about the first missing_facts item.
      A model-written progress statement is already visible when tools are allowed; do not repeat it.
      Always produce visible prose after read-only work. Proposal workflows receive a separate final response after preparation.
    TEXT
  end

  def run_completion(agent)
    @broadcaster.turn_status(@turn.allowed_tools.any? ? "Working…" : "Thinking…")
    compact_context

    with_provider_retries do
      agent.complete do |chunk|
        @broadcaster.append_assistant_chunk(chunk.content) if chunk.content.present?
      end
    end
  end

  def no_visible_response_or_tool?
    turn_assistant_messages.where.not(content: [ nil, "" ]).none? && turn_tool_calls.none?
  end

  def ensure_final_response
    return unless turn_tool_calls.any?

    last_tool_message_id = turn_tool_calls.maximum(:llm_message_id)
    final_exists = turn_assistant_messages.where("id > ?", last_tool_message_id).where.not(content: [ nil, "" ]).exists?
    return if final_exists

    content = with_provider_retries { Llm::FinalResponse.new(chat: @chat, turn: @turn).call }
    raise RubyLLM::Error, "The model returned an empty final response" if content.blank?

    @chat.llm_messages.create!(role: "assistant", content: content)
  end

  def start_tool_call(tool_call)
    if @turn && !@turn.allowed_tools.include?(tool_call.name)
      raise InvalidToolCall, "#{tool_call.name} is not allowed for #{@turn.intent}"
    end

    @turn&.update!(status: "working")
    @turn ? @broadcaster.turn_status("Working…") : @broadcaster.remove_pending
    @current_tool_call = tool_call
    @running_tool_calls << tool_call
    persisted_tool_call(tool_call)&.update!(trace_status: "running")
    @broadcaster.tool_running(tool_call)
  end

  def finish_tool_call(result)
    payload = result.is_a?(RubyLLM::Tool::Halt) ? result.content : result
    status = tool_failure?(payload) ? "failed" : "completed"
    persist_tool_result(@current_tool_call, payload, status: status)

    if proposal?(payload)
      @publisher.publish(tool_call: @current_tool_call, result: payload)
      @proposal_published = true
    elsif status == "failed"
      @broadcaster.tool_failed(@current_tool_call, payload)
    else
      @broadcaster.tool_completed(@current_tool_call, payload)
    end

    @running_tool_calls.delete(@current_tool_call)
    @current_tool_call = nil
    payload
  end

  def update_transaction_session
    return unless @turn.intent == "transaction"

    session = @chat.llm_transaction_sessions.pending.order(:id).last
    return unless session

    if @proposal_published
      session.update!(status: "completed", last_question_message_id: nil)
      return
    end

    response = turn_assistant_messages.where.not(content: [ nil, "" ]).order(:id).last
    session.update!(status: "open", last_question_message_id: response.id) if response&.content.to_s.strip.end_with?("?")
  end

  def compact_context(force: false)
    return false unless force || @chat.needs_compaction?

    (@compactor || Llm::ChatCompactor.new(@chat)).call
  end

  def turn_assistant_messages
    @turn.output_messages.where(role: "assistant")
  end

  def turn_tool_calls
    Llm::ToolCall.joins(:llm_message)
      .where(llm_messages: { llm_turn_id: @turn.id })
  end

  def persisted_tool_call(tool_call)
    Llm::ToolCall.find_by(tool_call_id: tool_call.id)
  end

  def persist_tool_result(tool_call, payload, status:)
    persisted_tool_call(tool_call)&.update!(trace_status: status, trace_output: payload)
  end

  def tool_failure?(result)
    result.is_a?(Hash) && (result.key?(:error) || result.key?("error"))
  end

  def proposal?(result)
    result.is_a?(Hash) && (result[:proposal] || result["proposal"])
  end

  def fail_turn(message)
    @turn.fail!(message) if @turn&.persisted? && !@turn.status.in?(%w[completed failed])

    unless turn_assistant_messages.where(content: message).exists?
      @chat.llm_messages.create!(role: "assistant", content: message, response_turn: @turn)
    end
    @broadcaster.remove_turn_status
  end
end
