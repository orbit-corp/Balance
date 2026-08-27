class Llm::AccountProposalGrounding
  attr_reader :errors

  def initialize(chat:, data:)
    messages = chat.respond_to?(:active_context_messages) ? chat.active_context_messages : chat.llm_messages.to_a
    context = Llm::ActiveTransactionContext.new(
      messages,
      currency_code: chat.workspace.currency_code
    )
    candidate = [ data["reason"], *data.fetch("accounts").pluck("name") ].join(" ")
    @errors = context.text_grounded?(candidate) ? [] : [ "The proposed accounts do not match the active request" ]
  end

  def valid? = errors.empty?
  def invalid? = !valid?
end
