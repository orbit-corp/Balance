class Llm::ChatTurn
  TIMEOUT_SECONDS = 60
  MAX_PROVIDER_ATTEMPTS = 3
  MAX_TOOL_CALLS_PER_TURN = 10

  class TurnTimeout < StandardError; end
  class ToolCallLimitExceeded < StandardError; end

  def initialize(chat:, agent: nil, compactor: nil)
    @chat = chat
    @agent = agent
    @compactor = compactor
    @tool_calls_this_turn = 0
    @broadcaster = Llm::ChatBroadcaster.new(chat)
    @publisher = Llm::ProposalPublisher.new(chat: chat, broadcaster: @broadcaster)
  end

  def call
    attempts = 0

    begin
      attempts += 1
      Timeout.timeout(TIMEOUT_SECONDS, TurnTimeout) do
        agent = @agent || LedgerAgent.new(chat: @chat)
        agent.before_tool_call { |tool_call| start_tool_call(tool_call) }
        agent.after_tool_result { |result| finish_tool_call(result) }

        run_turn(agent)
        retry_silent_turn(agent)
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
  rescue ToolCallLimitExceeded
    report_failure("I stopped after reaching my tool-call limit for this turn. Please send a follow-up message to continue.")
  rescue StandardError => e
    Rails.logger.error("ChatTurn failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(10).to_a.join("\n")}")
    report_failure("I couldn't complete that accounting request. Please try again.")
  ensure
    @broadcaster.remove_pending
    @broadcaster.remove_empty_assistant_messages
  end

  private

  def run_turn(agent)
    @tool_calls_this_turn = 0
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

  def last_assistant_message
    @chat.llm_messages.where(role: "assistant").order(:id).last
  end

  def start_tool_call(tool_call)
    @tool_calls_this_turn += 1
    raise ToolCallLimitExceeded if @tool_calls_this_turn > MAX_TOOL_CALLS_PER_TURN

    @broadcaster.remove_empty_assistant_messages
    @current_tool_call = tool_call
    @broadcaster.tool_running(tool_call) unless exploratory?(tool_call)
  end

  def finish_tool_call(result)
    if tool_failure?(result)
      @broadcaster.remove_tool_call(@current_tool_call)
      @current_tool_call = nil
      return result
    end

    if proposal?(result)
      @publisher.publish(tool_call: @current_tool_call, result: result)
    elsif exploratory?(@current_tool_call)
      @broadcaster.tool_append_completed(@current_tool_call, result)
    else
      @broadcaster.tool_completed(@current_tool_call, result)
    end

    @current_tool_call = nil
  end

  def tool_failure?(result)
    result.is_a?(Hash) && result.key?(:error)
  end

  def exploratory?(tool_call)
    tool_call.name == "list_journal_entries"
  end

  def proposal?(result)
    result.is_a?(Hash) && result[:proposal]
  end

  def report_failure(message)
    @chat.llm_messages.create!(role: "assistant", content: message)
  end
end
