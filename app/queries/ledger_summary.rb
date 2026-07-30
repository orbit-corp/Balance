class LedgerSummary
  Period = Struct.new(:income_kobo, :expense_kobo, keyword_init: true) do
    def profit_kobo
      income_kobo - expense_kobo
    end
  end

  Card = Struct.new(:label, :current, :previous, keyword_init: true) do
    def profit_kobo
      current.profit_kobo
    end

    def income_kobo
      current.income_kobo
    end

    def expense_kobo
      current.expense_kobo
    end

    def change_pct
      base = previous.profit_kobo
      value = current.profit_kobo

      if base.zero?
        return 0.0 if value.zero?

        return value.positive? ? 100.0 : -100.0
      end

      ((value - base).to_f / base.abs * 100).round(1)
    end

    def up?
      current.profit_kobo >= previous.profit_kobo
    end
  end

  Balance = Struct.new(:account, :amount_kobo, keyword_init: true)

  RECENT_LIMIT = 20

  def initialize(workspace)
    @workspace = workspace
  end

  def today
    period_for(Date.current..Date.current)
  end

  def this_week
    period_for(Date.current.beginning_of_week..Date.current)
  end

  def this_month
    period_for(Date.current.beginning_of_month..Date.current)
  end

  def cards
    [
      Card.new(label: "Today", current: today, previous: period_for((Date.current - 1)..(Date.current - 1))),
      Card.new(label: "This week", current: this_week, previous: period_for((Date.current.beginning_of_week - 7)..(Date.current - 7))),
      Card.new(label: "This month", current: this_month, previous: period_for((Date.current.beginning_of_month - 1.month)..(Date.current - 1.month)))
    ]
  end

  def daily_series(days: 30)
    start = Date.current - (days - 1)
    rows = posted_postings
      .where(transactions: { occurred_on: start..Date.current })
      .group("transactions.occurred_on", "accounts.kind")
      .sum(:amount_kobo)

    (start..Date.current).map do |date|
      income = -(rows[[ date, income_kind ]] || 0)
      expense = rows[[ date, expense_kind ]] || 0
      { date: date, income_kobo: income, expense_kobo: expense, net_kobo: income - expense }
    end
  end

  def recent_transactions
    workspace.transactions.posted
      .includes(:customer, :account)
      .order(occurred_on: :desc, id: :desc)
      .limit(RECENT_LIMIT)
  end

  # What each money account holds, read straight off the ledger.
  def balances
    totals = Posting
      .joins(:recorded_transaction)
      .where(transactions: { workspace_id: workspace.id, status: posted_status })
      .group(:account_id)
      .sum(:amount_kobo)

    Ledger::ChartOfAccounts.money_accounts(workspace).map do |account|
      Balance.new(account: account, amount_kobo: totals[account.id] || 0)
    end
  end

  def drafts_count
    workspace.transactions.drafts.count
  end

  def drafts_total_kobo
    workspace.transactions.drafts.sum(:amount_kobo)
  end

  def uncategorised_count
    workspace.transactions.posted.where(category: Ledger::ChartOfAccounts::UNCATEGORISED).count
  end

  private

  attr_reader :workspace

  # Grouping on accounts.kind comes back cast through the enum, so the keys are
  # names ("income"), not the stored integers.
  def income_kind
    "income"
  end

  def expense_kind
    "expense"
  end

  def posted_status
    Transaction.statuses[:posted]
  end

  # Every money figure comes from postings — a draft has none, so it cannot reach a
  # total no matter which query asks.
  def posted_postings
    Posting
      .joins(:recorded_transaction, :account)
      .where(transactions: { workspace_id: workspace.id, status: posted_status })
  end

  def period_for(date_range)
    totals = posted_postings
      .where(transactions: { occurred_on: date_range })
      .group("accounts.kind")
      .sum(:amount_kobo)

    Period.new(
      income_kobo: -(totals[income_kind] || 0),
      expense_kobo: totals[expense_kind] || 0
    )
  end
end
