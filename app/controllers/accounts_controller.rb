class AccountsController < ApplicationController
  def index
    @summary = LedgerSummary.new(current_workspace)
    @balances = @summary.balances
  end

  # Sellers name their own accounts — "Bank" becomes "GTBank" the first time it matters.
  def update
    @account = current_workspace.accounts.asset.find(params[:id])

    if @account.update(account_params)
      redirect_to accounts_path, notice: "Account renamed."
    else
      redirect_to accounts_path, alert: @account.errors.full_messages.to_sentence
    end
  end

  private
    def account_params
      params.require(:account).permit(:name)
    end
end
