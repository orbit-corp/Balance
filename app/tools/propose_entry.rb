class ProposeEntry < RubyLLM::Tool
  SHAPES = {
    "money_spent" => { debit: :other_expense, credit: :cash },
    "money_received" => { debit: :cash, credit: :other_income },
    "lent_out" => {
      debit: :receivable, credit: :cash, counterparty_slot: :debit,
      undecided_note: "I couldn't tell whether this was a gift or a loan, so pick the account."
    },
    "loan_repaid_to_user" => {
      debit: :cash, credit: :receivable, counterparty_slot: :credit,
      undecided_note: "I couldn't tell which receivable this repayment closes out, so pick the account."
    },
    "borrowed_cash" => {
      debit: :cash, credit: :payable, counterparty_slot: :credit,
      undecided_note: "I don't have who this was borrowed from, so pick the account."
    },
    "bought_on_credit" => {
      debit: :other_expense, credit: :payable, counterparty_slot: :credit,
      undecided_note: "I don't have who this is owed to, so pick the account."
    },
    "debt_paid_off" => {
      debit: :payable, credit: :cash, counterparty_slot: :debit,
      undecided_note: "I couldn't tell which payable this closes out, so pick the account."
    },
    "bank_fee" => { debit: :bank_charges, credit: :cash },
    "opening_balance" => { debit: :cash, credit: :opening_balance },
    "money_in_unknown_source" => { debit: :cash, credit: :suspense },
    "money_out_unknown_reason" => { debit: :suspense, credit: :cash }
  }.freeze

  description "Propose how a transaction should be recorded as a balanced double-entry journal entry. " \
              "This does not record anything — the user must confirm the proposal before it is ever posted. " \
              "Pick the one shape that best matches the transaction; every shape fully determines both accounts. " \
              "Amounts are in naira, not kobo."

  params(
    type: "object",
    properties: {
      description: { type: "string", description: "short description of the transaction" },
      shape: { type: "string", enum: SHAPES.keys, description: "the one shape that best matches this transaction" },
      amount_naira: { type: "number", description: "amount in naira, e.g. 5000 for ₦5,000" },
      entry_date: { type: "string", description: "ISO date (YYYY-MM-DD) the transaction happened; defaults to today" },
      counterparty_name: { type: "string", description: "who the money is owed to/by, for shapes that involve a counterparty" },
      undecided: {
        type: "boolean",
        description: "set true when you genuinely cannot tell which account this shape's counterparty-driven " \
                     "side belongs to (e.g. gift vs. loan) — leaves that account blank for the user to pick"
      }
    },
    required: %w[description shape amount_naira]
  )

  def initialize(workspace)
    @workspace = workspace
  end

  def execute(description:, shape:, amount_naira:, entry_date: nil, counterparty_name: nil, undecided: false)
    spec = SHAPES[shape]
    return { error: "\"#{shape}\" is not a shape I know. Must be one of: #{SHAPES.keys.join(', ')}" } unless spec
    return { error: "description is required" } if description.blank?
    return { error: "amount_naira must be greater than zero" } unless amount_naira.to_f.positive?

    date = parse_date(entry_date)
    return { error: "entry_date must be a valid ISO date (YYYY-MM-DD)" } if entry_date && date.nil?

    amount_kobo = (amount_naira.to_f * 100).round
    blank_slot = spec[:counterparty_slot] if undecided || (spec[:counterparty_slot] && counterparty_name.blank?)

    debit_account = blank_slot == :debit ? nil : Account.for_role!(@workspace, spec[:debit])
    credit_account = blank_slot == :credit ? nil : Account.for_role!(@workspace, spec[:credit])

    lines = [
      { "account_id" => debit_account&.id, "side" => "debit", "amount_kobo" => amount_kobo,
        "counterparty_name" => counterparty_name },
      { "account_id" => credit_account&.id, "side" => "credit", "amount_kobo" => amount_kobo,
        "counterparty_name" => counterparty_name }
    ]

    {
      proposal: true,
      proposed_action: "journal_entry",
      entry_data: {
        "description" => description,
        "entry_date" => date.to_s,
        "shape" => shape,
        "needs_attention" => blank_slot ? spec[:undecided_note] : nil,
        "lines" => lines
      },
      message: "Proposal created and shown to the user for confirmation."
    }
  end

  private

  def parse_date(entry_date)
    entry_date ? Date.iso8601(entry_date) : Date.current
  rescue ArgumentError
    nil
  end
end
