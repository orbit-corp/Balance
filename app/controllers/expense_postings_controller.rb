class ExpensePostingsController < ApplicationController
  def create
    @expense = current_workspace.expenses.find(params[:expense_id])
    result = @expense.post

    if result.success?
      redirect_to expenses_path, notice: "Expense posted."
    else
      @journal_entry = result.entry
      @engine_result = Accounting::Engine.check(@journal_entry.journal_entry_lines)
      @possible_duplicates = @expense.possible_duplicates.limit(5)
      @posting_errors = result.errors
      render "expenses/show", status: :unprocessable_content
    end
  end
end
