class ExpensePostingsController < ApplicationController
  def create
    @expense = current_workspace.expenses.find(params[:expense_id])
    result = @expense.post

    if result.success?
      redirect_to expenses_path, notice: "Expense posted."
    else
      @journal_entry = result.entry
      @engine_result = Accounting::Engine.check(@journal_entry.journal_entry_lines)
      flash.now[:alert] = result.errors.to_sentence
      render "expenses/show", status: :unprocessable_content
    end
  end
end
