class Llm::ProposalGrounding
  attr_reader :errors

  def initialize(chat:, data:)
    @workspace = chat.workspace
    @context = Llm::ActiveTransactionContext.new(
      chat.llm_messages.to_a,
      currency_code: chat.workspace.currency_code
    )
    @data = data
    @errors = validate
  end

  def valid? = errors.empty?
  def invalid? = !valid?

  private

  attr_reader :context, :data, :workspace

  def validate
    messages = []
    messages << "The proposal description does not match the active transaction" unless context.text_grounded?(data["description"])

    if context.transaction?
      unsupported = data.fetch("lines").pluck("amount_kobo").uniq.reject { |amount| context.supported_amount?(amount) }
      messages << "Unsupported amounts: #{unsupported.map { |amount| format('%.2f', amount.to_i / 100.0) }.join(', ')}" if unsupported.any?
      messages.concat(account_side_errors)
    else
      messages << "No user-provided transaction amount is active"
    end

    expected_date = context.expected_entry_date
    if expected_date && data["entry_date"] != expected_date.iso8601
      messages << "Entry date #{data['entry_date']} does not match #{expected_date.iso8601}"
    end
    messages
  end

  def account_side_errors
    accounts = workspace.accounts.where(id: data.fetch("lines").pluck("account_id")).index_by { |account| account.id.to_s }

    data.fetch("lines").filter_map do |line|
      account = accounts[line["account_id"].to_s]
      next unless account
      next if account.base_type == "expense" && line["side"] == "debit"
      next if account.base_type == "income" && line["side"] == "credit"
      next unless %w[expense income].include?(account.base_type)

      "#{account.name} cannot be #{line['side']}ed for this transaction"
    end
  end
end
