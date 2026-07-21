class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[edit update destroy]

  def index
    @transactions = current_workspace.transactions.includes(:customer).order(occurred_on: :desc, id: :desc)
  end

  def new
    kind = params[:kind] || "income"
    default_category = kind == "expense" ? "Other" : "Sales"

    @transaction = current_workspace.transactions.build(
      kind: kind,
      category: default_category,
      occurred_on: params[:occurred_on].presence || Date.current,
      description: params[:description]
    )
    @transaction.amount = params[:amount] if params[:amount].present?
  end

  def create
    # Recording from the WhatsApp review queue: resolve (and guard against double-recording)
    # the source extraction before building the transaction.
    if params[:whatsapp_document_extraction_id].present?
      @extraction = current_workspace.whatsapp_document_extractions.recordable.find_by(id: params[:whatsapp_document_extraction_id])
      if @extraction.nil?
        redirect_to document_reviews_path, alert: "That document was already recorded or is no longer available."
        return
      end
    end

    @transaction = current_workspace.transactions.build(transaction_params)
    if @extraction
      @transaction.source = :whatsapp
      @transaction.whatsapp_message = @extraction.whatsapp_message
    end

    if @transaction.save
      @extraction&.update!(review_status: :recorded, recorded_transaction: @transaction)

      if @extraction
        redirect_to document_reviews_path, notice: "Transaction recorded from WhatsApp."
      else
        @summary = LedgerSummary.new(current_workspace)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to dashboard_path }
        end
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
