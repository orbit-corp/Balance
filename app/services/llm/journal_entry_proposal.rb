class Llm::JournalEntryProposal
  attr_reader :data, :errors

  def self.from_tool(workspace:, description:, entry_date:, lines:)
    new(
      workspace: workspace,
      data: {
        "description" => description,
        "entry_date" => entry_date || Date.current.to_s,
        "lines" => lines.map do |line|
          {
            "account_id" => (line[:account_id] || line["account_id"]).presence&.to_i,
            "side" => line[:side] || line["side"],
            "amount_kobo" => amount_to_kobo(line[:amount_naira] || line["amount_naira"]),
            "counterparty_name" => line[:counterparty_name] || line["counterparty_name"]
          }
        end
      }
    )
  end

  def self.from_form(workspace:, params:)
    new(
      workspace: workspace,
      data: {
        "description" => params[:description],
        "entry_date" => params[:entry_date],
        "lines" => (params[:lines] || {}).values.map do |line|
          {
            "account_id" => line[:account_id].presence&.to_i,
            "side" => line[:side],
            "amount_kobo" => amount_to_kobo(line[:amount_naira].presence),
            "counterparty_name" => line[:counterparty_name].presence
          }
        end
      }
    )
  end

  def self.amount_to_kobo(value)
    raw = sanitize_currency_string(value)
    return nil if raw.blank?

    (BigDecimal(raw) * 100).round
  rescue ArgumentError
    nil
  end

  def self.sanitize_currency_string(value)
    value.to_s.gsub(/[^\d.]/, "")
  end

  private_class_method :sanitize_currency_string

  def initialize(workspace:, data:)
    @workspace = workspace
    @data = data
    @errors = []
    validate
  end

  def valid?
    errors.empty?
  end

  def invalid?
    !valid?
  end

  def build_journal_entry!
    entry = @workspace.journal_entries.build(
      description: data["description"],
      entry_date: Date.iso8601(data["entry_date"])
    )

    data["lines"].each do |line|
      journal_entry_line = entry.journal_entry_lines.build(account: @workspace.accounts.find(line["account_id"]))
      line["side"] == "debit" ? journal_entry_line.debit_kobo = line["amount_kobo"] : journal_entry_line.credit_kobo = line["amount_kobo"]
    end

    entry.save!
    entry
  end

  private

  def validate
    errors << "description is required" if data["description"].blank?
    errors << "date is required" if data["entry_date"].blank? || !valid_date?
    errors << "an entry needs at least two lines" if data["lines"].size < 2

    data["lines"].each do |line|
      errors << "every line needs an account" if line["account_id"].blank?
      errors << "each line must be a debit or credit" unless line["side"].in?(%w[debit credit])
      errors << "each line amount must be greater than zero" unless line["amount_kobo"].to_i.positive?
    end

    account_ids = data["lines"].pluck("account_id").compact
    errors << "an account on this entry does not belong to this workspace" unless account_ids.all? { |id| @workspace.accounts.exists?(id: id) }
    errors << "debits and credits must balance" if balanced? == false
  end

  def valid_date?
    Date.iso8601(data["entry_date"])
    true
  rescue ArgumentError, TypeError
    false
  end

  def balanced?
    debit_total = data["lines"].sum { |line| line["side"] == "debit" ? line["amount_kobo"].to_i : 0 }
    credit_total = data["lines"].sum { |line| line["side"] == "credit" ? line["amount_kobo"].to_i : 0 }
    debit_total == credit_total
  end
end
