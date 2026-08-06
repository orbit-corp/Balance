class ProposeEntry < RubyLLM::Tool
  description "Propose how a transaction should be recorded as a balanced double-entry journal entry. " \
              "This does not record anything — it only returns a preview. Amounts are in naira, not kobo. " \
              "Only use account ids returned by list_accounts; never invent one."

  params(
    type: "object",
    properties: {
      description: { type: "string", description: "short description of the transaction" },
      lines: {
        type: "array",
        description: "at least two lines; total debits must equal total credits",
        items: {
          type: "object",
          properties: {
            account_id: { type: "integer", description: "an id returned by list_accounts" },
            side: { type: "string", enum: %w[debit credit] },
            amount_naira: { type: "number", description: "amount in naira, e.g. 5000 for ₦5,000" }
          },
          required: %w[account_id side amount_naira]
        }
      }
    },
    required: %w[description lines]
  )

  def initialize(workspace)
    @workspace = workspace
  end

  def execute(description:, lines:)
    error = validation_error(lines)
    return halt("Can't record this: #{error}") if error

    halt(format_proposal(description, lines))
  end

  private

  def validation_error(lines)
    return "an entry needs at least two lines" if lines.size < 2

    accounts = @workspace.accounts.where(id: lines.map { |l| l["account_id"] || l[:account_id] }).index_by(&:id)

    lines.each do |line|
      account_id = line["account_id"] || line[:account_id]
      side = line["side"] || line[:side]

      return "account #{account_id} does not exist in this workspace" unless accounts.key?(account_id)
      return "\"#{side}\" is not a valid side, must be debit or credit" unless %w[debit credit].include?(side)
    end

    debit_kobo = kobo_total(lines, "debit")
    credit_kobo = kobo_total(lines, "credit")
    return "debits (₦#{format_naira(debit_kobo)}) do not equal credits (₦#{format_naira(credit_kobo)})" if debit_kobo != credit_kobo

    nil
  end

  def kobo_total(lines, side)
    lines.select { |l| (l["side"] || l[:side]) == side }
         .sum { |l| to_kobo(l["amount_naira"] || l[:amount_naira]) }
  end

  def to_kobo(amount_naira)
    (amount_naira.to_f * 100).round
  end

  def format_naira(kobo)
    format("%.2f", kobo / 100.0)
  end

  def format_proposal(description, lines)
    account_names = @workspace.accounts.where(id: lines.map { |l| l["account_id"] || l[:account_id] }).index_by(&:id)

    formatted_lines = lines.map do |line|
      account_id = line["account_id"] || line[:account_id]
      side = line["side"] || line[:side]
      amount_naira = line["amount_naira"] || line[:amount_naira]
      name = account_names[account_id].name

      "  #{side.capitalize.ljust(6)} #{name.ljust(24)} ₦#{format("%.2f", amount_naira.to_f)}"
    end

    "Proposed entry — #{description}\n#{formatted_lines.join("\n")}"
  end
end
