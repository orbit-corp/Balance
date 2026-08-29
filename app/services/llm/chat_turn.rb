class Llm::ChatTurn
  TIMEOUT_SECONDS = 180
  MAX_PROVIDER_ATTEMPTS = 3

  class TurnTimeout < StandardError; end

  def initialize(chat:, turn: nil, agent: nil, compactor: nil)
    @chat = chat
    @turn = turn || chat.llm_turns.where(status: "queued").order(:id).first
    @agent = agent
    @compactor = compactor
    @running_tool_calls = []
    @failed_tool_calls = []
    @broadcaster = Llm::ChatBroadcaster.new(chat, turn: @turn)
    @publisher = Llm::ProposalPublisher.new(chat: chat, broadcaster: @broadcaster)
  end

  def call
    return unless @turn
    return if @turn.status.in?(%w[completed failed])

    @chat.active_turn = @turn
    Llm::Current.turn = @turn
    @turn.update!(status: "responding", started_at: Time.current)
    @broadcaster.turn_status("Working…")

    Timeout.timeout(TIMEOUT_SECONDS, TurnTimeout) { run_model }

    @turn.finish!
    @broadcaster.remove_turn_status
  rescue TurnTimeout
    fail_turn("I couldn't finish this request in time. Please try again.")
  rescue RubyLLM::Error, Faraday::ConnectionFailed
    fail_turn("The accounting assistant is temporarily unavailable. Please try again.")
  rescue StandardError => error
    Rails.logger.error("ChatTurn failed: #{error.class}: #{error.message}\n#{error.backtrace&.first(10).to_a.join("\n")}")
    fail_turn("I hit a problem while answering. Please try again.")
  ensure
    @running_tool_calls.each { |tool_call| @broadcaster.remove_tool_call(tool_call) }
    @broadcaster.remove_empty_assistant_messages
    @chat.active_turn = nil
    Llm::Current.reset
  end

  private

  def run_model
    agent = @agent || LedgerAgent.new(chat: @chat)
    agent.before_tool_call { |tool_call| start_tool_call(tool_call) }
    agent.after_tool_result { |result| finish_tool_call(result) }

    result = run_completion(agent)
    run_completion(agent) if result.is_a?(RubyLLM::Tool::Halt) && !@published_proposal
    run_completion(agent) if !@published_proposal && visible_turn_response.blank?
    raise RubyLLM::Error, "The model returned an empty response" if !@published_proposal && visible_turn_response.blank?
  end

  def run_completion(agent)
    @broadcaster.turn_status("Working…")
    compact_context
    Llm::Current.visible_response = true

    with_provider_retries do
      agent.complete do |chunk|
        @broadcaster.append_assistant_chunk(chunk.content) if chunk.content.present?
      end
    end
  ensure
    Llm::Current.visible_response = false
    @broadcaster.finalize_assistant_message
  end

  def start_tool_call(tool_call)
    @turn.update!(status: "working")
    @broadcaster.turn_status("Working…")
    unless @activity_published
      @broadcaster.action(tool_call)
      @activity_published = true
    end
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
      @published_proposal = @publisher.publish(tool_call: @current_tool_call, result: payload)
      @failed_tool_calls.select { |tool_call| tool_call.name == @current_tool_call.name }.each do |tool_call|
        @broadcaster.remove_tool_call(tool_call)
        @failed_tool_calls.delete(tool_call)
      end
    elsif status == "failed"
      @broadcaster.tool_failed(@current_tool_call, payload)
      @failed_tool_calls << @current_tool_call
    else
      @broadcaster.tool_completed(@current_tool_call, payload)
    end

    @running_tool_calls.delete(@current_tool_call)
    @current_tool_call = nil
    payload
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

  def compact_context(force: false)
    return false unless force || @chat.needs_compaction?

    (@compactor || Llm::ChatCompactor.new(@chat)).call
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

  def turn_assistant_messages
    @turn.output_messages.where(role: "assistant")
  end

  def visible_turn_response
    turn_assistant_messages.where(internal: false).where.not(content: [ nil, "" ]).order(:id).last&.content
  end

  def fail_turn(message)
    @turn.fail!(message) if @turn&.persisted? && !@turn.status.in?(%w[completed failed])

    unless turn_assistant_messages.where(content: message).exists?
      @chat.llm_messages.create!(
        role: "assistant",
        content: message,
        response_turn: @turn,
        visible_response: true
      )
    end
    @broadcaster.remove_turn_status
  end
end
