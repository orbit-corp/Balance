class Llm::ActiveTransactionContext
  TRANSACTION_PATTERN = /\b(paid|pay|received|receive|sold|sell|bought|buy|gave|give|withdrew|withdraw|deposited|deposit|earned|charged|owe|owed|lent|borrowed)\b/i
  NAIRA_PATTERN = /(?:₦|\bNGN\s*)([\d,]+(?:\.\d+)?)([km])?/i
  SHORTHAND_PATTERN = /\b(\d+(?:\.\d+)?)\s*([km])\b/i
  DOLLAR_PATTERN = /\$\s*([\d,]+(?:\.\d+)?)/
  BARE_AMOUNT_PATTERN = /\b(\d[\d,]*(?:\.\d+)?)\b/
  PERCENT_PATTERN = /(\d+(?:\.\d+)?)\s*%/
  WORD_PATTERN = /[[:alnum:]]+/
  STOP_WORDS = %w[
    about account accounts actual add after again amount and another are been before being can cash
    create did does entry for from had has have into its latest money need now of on once one or our
    paid payment please proposal record recorded recording should that the their them then there these
    they this to today transaction user was were what when which with would you your
  ].freeze
  NORMAL_FORMS = {
    "bought" => "buy", "gave" => "give", "given" => "give", "lent" => "lend",
    "owed" => "owe", "paid" => "pay", "received" => "receive", "sold" => "sell",
    "withdrew" => "withdraw", "withdrawn" => "withdraw"
  }.freeze

  attr_reader :currency_code, :messages

  def initialize(messages, currency_code:)
    @currency_code = currency_code
    dialogue = Array(messages).reject { |message| message.role.to_s == "system" }
    @messages = active_messages(dialogue)
  end

  def user_text
    @user_text ||= messages.select { |message| message.role.to_s == "user" }.map(&:content).join("\n")
  end

  def transaction?
    explicit_amounts.any? && user_text.match?(TRANSACTION_PATTERN)
  end

  def clarification_question
    return unless transaction?

    if generic_receipt? && !receipt_nature_known?
      "What was the #{formatted_primary_amount} for—income, a gift, repayment, or something else?"
    elsif generic_receipt? && !payment_source_known?
      verb = user_text.match?(/\b(received|receive|sold|sell|earned)\b/i) ? "receive" : "pay"
      "How did you #{verb} the #{formatted_primary_amount}—cash, bank transfer, card, or another way?"
    end
  end

  def text_grounded?(candidate)
    source = terms(user_text)
    proposed = terms(candidate)
    return false if source.any? && proposed.empty?

    source.empty? || (source & proposed).any?
  end

  def supported_amount?(amount_kobo)
    supported_amounts.include?(amount_kobo.to_i)
  end

  def response_amounts_grounded?(response)
    extract_naira(response).all? { |amount| supported_amount?(amount) }
  end

  def expected_entry_date
    return Date.current if user_text.match?(/\btoday\b/i)
    return Date.yesterday if user_text.match?(/\byesterday\b/i)

    iso = user_text.scan(/\b\d{4}-\d{2}-\d{2}\b/).last
    Date.iso8601(iso) if iso
  rescue Date::Error
    nil
  end

  private

  def generic_receipt?
    user_text.match?(/\b(received|receive)\b/i)
  end

  def receipt_nature_known?
    user_text.match?(/\b(sold|sale|salary|wage|gift|loan|borrow|repay|refund|reimburse|income|interest|dividend|rent|invoice|customer|client|contribution)\w*\b/i)
  end

  def payment_source_known?
    user_text.match?(/\b(cash|bank|transfer|card|wallet|credit|receivable|payable|cheque|checking|savings)\b/i)
  end

  def formatted_primary_amount
    amount = BigDecimal(explicit_amounts.first.to_s) / 100
    formatted = amount.frac.zero? ? amount.to_i.to_fs(:delimited) : format("%.2f", amount)
    currency_code == "NGN" ? "₦#{formatted}" : "#{formatted} #{currency_code}"
  end

  def active_messages(dialogue)
    anchor = dialogue.rindex do |message|
      message.role.to_s == "user" && money_signal?(message.content)
    end
    anchor ? dialogue.drop(anchor) : dialogue.last(12)
  end

  def money_signal?(content)
    content.to_s.match?(NAIRA_PATTERN) || content.to_s.match?(SHORTHAND_PATTERN) ||
      content.to_s.match?(DOLLAR_PATTERN) || bare_transaction_amounts(content).any?
  end

  def terms(text)
    text.to_s.downcase.scan(WORD_PATTERN).filter_map do |word|
      next if word.length < 3 || STOP_WORDS.include?(word) || word.match?(/\A\d+\z/)

      NORMAL_FORMS.fetch(word, word.delete_suffix("s"))
    end.uniq
  end

  def explicit_amounts
    @explicit_amounts ||= extract_naira(user_text).presence || extract_shorthand(user_text).presence ||
      bare_transaction_amounts(user_text)
  end

  def extract_naira(text)
    text.to_s.scan(NAIRA_PATTERN).map { |number, suffix| amount_to_minor_units(number, suffix) }
  end

  def extract_shorthand(text)
    text.to_s.scan(SHORTHAND_PATTERN).map { |number, suffix| amount_to_minor_units(number, suffix) }
  end

  def bare_transaction_amounts(text)
    text.to_s.lines.filter_map do |line|
      next unless line.match?(TRANSACTION_PATTERN)
      next if line.match?(NAIRA_PATTERN) || line.match?(SHORTHAND_PATTERN) || line.match?(DOLLAR_PATTERN)

      without_dates = line.gsub(/\b\d{4}-\d{2}-\d{2}\b/, "")
      without_dates.scan(BARE_AMOUNT_PATTERN).flatten.map { |number| amount_to_minor_units(number, nil) }
    end.flatten
  end

  def amount_to_minor_units(number, suffix)
    multiplier = { "k" => 1_000, "m" => 1_000_000 }.fetch(suffix.to_s.downcase, 1)
    (BigDecimal(number.delete(",")) * multiplier * 100).round
  end

  def supported_amounts
    @supported_amounts ||= begin
      values = explicit_amounts.dup
      base = values.max
      percentages = user_text.scan(PERCENT_PATTERN).flatten.map { |value| BigDecimal(value) }
      values.concat(percentages.map { |percentage| (base * percentage / 100).round }) if base
      values.concat(foreign_currency_amounts)

      sums = subset_sums(values.uniq)
      differences = sums.product(sums).filter_map { |left, right| left - right if left > right }
      (sums + differences).select(&:positive?).uniq
    end
  end

  def subset_sums(values)
    values.first(10).each_with_object([ 0 ]) do |value, sums|
      sums.concat(sums.map { |sum| sum + value })
    end.uniq
  end

  def foreign_currency_amounts
    dollars = user_text.scan(DOLLAR_PATTERN).flatten.map { |value| BigDecimal(value.delete(",")) }
    return [] if dollars.empty? || !user_text.match?(/(?:\/\$|per dollar)/i)

    dollars.product(extract_naira(user_text)).map { |dollar, rate_kobo| (dollar * rate_kobo).round }
  end
end
