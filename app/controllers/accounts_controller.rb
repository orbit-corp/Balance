class AccountsController < ApplicationController
  before_action :set_account, only: %i[update]

  def index
    @accounts = current_workspace.accounts.order(:name)
  end

  def new
    @account = current_workspace.accounts.build
  end

  def create
    @account = current_workspace.accounts.build(account_params)

    if @account.save
      redirect_to accounts_path, notice: "Account created."
    else
      flash.now[:alert] = @account.errors.full_messages.to_sentence
      render_account_form_error
    end
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "Account updated."
    else
      redirect_to accounts_path, alert: @account.errors.full_messages.to_sentence
    end
  end

  private
    def set_account
      @account = current_workspace.accounts.find(params[:id])
    end

    def account_params
      params.require(:account).permit(:name, :base_type, :account_type, :detail_type, :description)
    end

    def render_account_form_error
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("modal", partial: "accounts/modal_form", locals: { account: @account }),
                 status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
end
