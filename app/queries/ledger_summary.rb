class LedgerSummary
  Period = Struct.new(:income_kobo, :expense_kobo, keyword_init: true) do
    def profit_kobo
      income_kobo - expense_kobo
    end
  end

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

  def recent_transactions
    workspace.transactions
      .includes(:category, :customer)
      .order(occurred_on: :desc, id: :desc)
      .limit(RECENT_LIMIT)
  end

  private

  attr_reader :workspace

  def period_for(date_range)
    totals = workspace.transactions
      .where(occurred_on: date_range)
      .group(:kind)
      .sum(:amount_kobo)

    Period.new(
      income_kobo: totals["income"] || 0,
      expense_kobo: totals["expense"] || 0
    )
  end
end
