class Llm::ProposalGrounding
  attr_reader :errors

  def initialize(chat:, data:)
    @chat = chat
    @workspace = chat.workspace
    messages = chat.respond_to?(:active_context_messages) ? chat.active_context_messages : chat.llm_messages.to_a
    @context = Llm::ActiveTransactionContext.new(
      messages,
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
      messages.concat(transaction_semantic_errors)
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

  def transaction_semantic_errors
    turn = @chat.active_turn if @chat.respond_to?(:active_turn)
    classification = turn&.classification.to_h.dig("transaction", "classification").to_s
    return [] unless classification.match?(/repay/i) && context.user_text.match?(/\b(received|receive)\b/i)

    credit_accounts = accounts_for_lines("credit")
    return [] if credit_accounts.any? { |account| receivable_account?(account) }

    [ "A received repayment must credit a loans or receivables asset account; propose that missing account instead of treating the receipt as income" ]
  end

  def accounts_for_lines(side)
    ids = data.fetch("lines").select { |line| line["side"] == side }.pluck("account_id")
    workspace.accounts.where(id: ids)
  end

  def receivable_account?(account)
    account.base_type == "asset" &&
      [ account.name, account.account_type, account.detail_type ].join(" ").match?(/receivable|loan/i)
  end
end
