class ExpenseReport
  Ranking = Data.define(:label, :amount_kobo)

  def initialize(workspace, date_range:, vendor_id: nil, category_id: nil)
    @workspace = workspace
    @date_range = date_range
    @vendor_id = vendor_id
    @category_id = category_id
  end

  def total_kobo
    expense_lines.sum(:amount_kobo)
  end

  def monthly_totals
    expense_lines
      .group(Arel.sql("DATE_TRUNC('month', expenses.payment_date)"))
      .order(Arel.sql("DATE_TRUNC('month', expenses.payment_date)"))
      .sum(:amount_kobo)
      .transform_keys(&:to_date)
  end

  def top_vendors(limit: 5)
    expense_lines
      .joins(expense: :payee_contact)
      .group("contacts.id", "contacts.name")
      .order(Arel.sql("SUM(expense_lines.amount_kobo) DESC"))
      .limit(limit)
      .sum(:amount_kobo)
      .map { |(_id, name), amount| Ranking.new(label: name, amount_kobo: amount) }
  end

  def top_categories(limit: 5)
    expense_lines
      .joins(:account)
      .group("accounts.id", "accounts.name")
      .order(Arel.sql("SUM(expense_lines.amount_kobo) DESC"))
      .limit(limit)
      .sum(:amount_kobo)
      .map { |(_id, name), amount| Ranking.new(label: name, amount_kobo: amount) }
  end

  def category_trends
    rows = expense_lines
      .joins(:account)
      .group(Arel.sql("DATE_TRUNC('month', expenses.payment_date)"), "accounts.id", "accounts.name")
      .order(Arel.sql("DATE_TRUNC('month', expenses.payment_date)"))
      .sum(:amount_kobo)

    rows.group_by { |(_month, _id, name), _amount| name }.map do |name, category_rows|
      {
        name: name,
        data: category_rows.to_h { |(month, _id, _name), amount| [ month.to_date, amount / 100.0 ] }
      }
    end
  end

  private
    attr_reader :workspace, :date_range, :vendor_id, :category_id

    def expense_lines
      @expense_lines ||= ExpenseLine.joins(:expense)
        .where(expenses: { workspace_id: workspace.id, status: "posted", payment_date: date_range })
        .then { |lines| vendor_id.present? ? lines.where(expenses: { payee_contact_id: vendor_id }) : lines }
        .then { |lines| category_id.present? ? lines.where(account_id: category_id) : lines }
    end
end
