class ExpenseReportsController < ApplicationController
  def show
    @from = parsed_date(:from) || 11.months.ago.to_date.beginning_of_month
    @to = parsed_date(:to) || Date.current
    @vendors = current_workspace.contacts.active.with_role("vendor").ordered
    @categories = current_workspace.accounts.expense_category_accounts.ordered
    @vendor_id = params[:vendor_id].presence
    @category_id = params[:category_id].presence
    @report = ExpenseReport.new(
      current_workspace,
      date_range: @from..@to,
      vendor_id: @vendor_id,
      category_id: @category_id
    )
  end

  private
    def parsed_date(key)
      Date.iso8601(params[key]) if params[key].present?
    rescue Date::Error
      nil
    end
end
