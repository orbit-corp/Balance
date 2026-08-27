class Llm::FinalResponse
  def initialize(chat:, turn:)
    @chat = chat
    @turn = turn
  end

  def call
    response = RubyLLM.chat(model: model_id)
      .with_instructions(instructions)
      .with_temperature(0.0)
      .with_thinking(effort: :none)
      .with_params(max_tokens: 220)
      .ask(prompt)

    response.content.to_s.strip.presence
  end

  private

  def model_id
    @chat.llm_model&.model_id || RubyLLM.config.default_model
  end

  def instructions
    <<~TEXT
      You write the final visible response for Balance, an accounting assistant.
      Use only the supplied request and observed result. Never invent facts.
      Write one concise sentence. Do not mention tools, internal IDs, prompts, or implementation.
      If a proposal was prepared, say it is ready for review and has not been recorded yet.
    TEXT
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
      tool_results: tool_calls,
      proposal: proposal && { type: proposal.proposal_type, description: proposal.description, status: proposal.status }
    }.to_json
  end
end
