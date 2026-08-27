class GetBalanceSummary < RubyLLM::Tool
  description "Show this workspace's current account balances and income, expense, and net balance for today, this week, and this month. It is read-only and includes posted entries only."

  def initialize(workspace)
    @workspace = workspace
  end

  def execute
    summary = LedgerSummary.new(@workspace)

    {
      periods: {
        "Today" => period_data(summary.today),
        "This week" => period_data(summary.this_week),
        "This month" => period_data(summary.this_month)
      },
      account_balances: summary.trial_balance.map do |line|
        {
          account: line.account.name,
          balance_naira: format_amount(line.debit_kobo.positive? ? line.debit_kobo : -line.credit_kobo),
          normal_side: line.debit_kobo.positive? ? "debit" : "credit"
        }
      end
    }
  end

  private

  def period_data(period)
    {
      income_naira: format_amount(period.income_kobo),
      expense_naira: format_amount(period.expense_kobo),
      net_naira: format_amount(period.profit_kobo)
    }
  end

  def format_amount(kobo)
    format("%.2f", BigDecimal(kobo.to_i) / 100)
  end
end
