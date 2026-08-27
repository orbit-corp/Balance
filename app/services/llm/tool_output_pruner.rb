class Llm::ToolOutputPruner
  def initialize(chat)
    @chat = chat
  end

  def call
    budget = Llm::Chat::PRUNE_PROTECT_TOKENS
    tool_messages = @chat.llm_messages.where(role: "tool", summarized_at: nil).order(:created_at, :id).to_a

    tool_messages.reverse_each do |message|
      budget -= Llm::Chat.estimated_tokens(message.content)
      message.update!(summarized_at: Time.current) if budget.negative?
    end
  end
end
