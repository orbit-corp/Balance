class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[edit update destroy]

  def index
    @transactions = current_workspace.transactions.includes(:customer).order(occurred_on: :desc, id: :desc)
  end

  def new
    kind = params[:kind] || "income"
    default_category = kind == "expense" ? "Other" : "Sales"

    @transaction = current_workspace.transactions.build(kind: kind, category: default_category, occurred_on: Date.current)
  end

  def create
    @transaction = current_workspace.transactions.build(transaction_params)

    if @transaction.save
      @summary = LedgerSummary.new(current_workspace)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to dashboard_path }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @transaction.update(transaction_params)
      @summary = LedgerSummary.new(current_workspace)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to dashboard_path }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    @summary = LedgerSummary.new(current_workspace)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to dashboard_path }
    end
  end

  private
    def set_transaction
      @transaction = current_workspace.transactions.find(params[:id])
    end

    def transaction_params
      params.require(:transaction).permit(:kind, :amount, :category, :customer_id, :occurred_on, :description)
    end
end
