class AccountsController < ApplicationController
  before_action :set_account, only: %i[edit update destroy]

  def index
    @accounts = current_workspace.accounts.order(:name)
  end

  def new
    @account = current_workspace.accounts.build
  end

  def create
    @account = current_workspace.accounts.build(account_params)

    if @account.save
      redirect_out_of_frame accounts_path, notice: "Account created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "Account updated."
    else
      redirect_to accounts_path, alert: @account.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @account.destroy
      redirect_to accounts_path, notice: "Account deleted."
    else
      redirect_to accounts_path, alert: @account.errors.full_messages.to_sentence.presence || "This account cannot be deleted."
    end
  end

  private
    def set_account
      @account = current_workspace.accounts.find(params[:id])
    end

    def account_params
      params.expect(account: [ :name, :base_type, :account_type, :detail_type, :description ])
    end
end
