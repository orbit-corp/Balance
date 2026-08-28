class Llm::FinalResponse
  InvalidResponse = Class.new(StandardError)

  def initialize(chat:, turn:)
    @chat = chat
    @turn = turn
  end

  def call
    response = agent.ask(prompt)
    answer = response.content.to_h.deep_stringify_keys.fetch("answer").to_s.strip
    raise InvalidResponse, "The final response was empty" if answer.blank?

    answer
  end

  private

  def model_id
    @chat.llm_model&.model_id || RubyLLM.config.default_model
  end

  def agent
    FinalResponseAgent.new(
      model: model_id,
      workspace_type: @chat.workspace.workspace_type,
      currency_code: @chat.workspace.currency_code,
      today: Date.current.iso8601
    )
  end

  def prompt
    tool_calls = Llm::ToolCall.joins(:llm_message)
      .where(llm_messages: { llm_turn_id: @turn.id })
      .order(:id)
      .map { |call| { name: call.name, result: call.display_output } }

    proposal = @chat.proposals.joins(:llm_message)
      .where(llm_messages: { llm_turn_id: @turn.id })
      .order(:id)
      .last

    {
      user_request: @turn.user_message.content,
      classified_intent: @turn.intent,
      relationship: @turn.relationship,
      transaction: @turn.classification["transaction"],
      tool_results: tool_calls,
      proposal: proposal && { type: proposal.proposal_type, description: proposal.description, status: proposal.status }
    }.to_json
  end
end
