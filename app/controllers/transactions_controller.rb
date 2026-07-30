class TransactionsController < ApplicationController
  include Pagy::Method

  PER_PAGE = 20
  FILTERS = %w[all income expense draft].freeze

  before_action :set_transaction, only: %i[edit update destroy post_to_books]

  def index
    load_ledger
  end

  def new
    kind = params[:kind] || "income"
    default_category = kind == "expense" ? "Other" : "Sales"

    @transaction = current_workspace.transactions.build(
      kind: kind,
      category: default_category,
      account: Ledger::ChartOfAccounts.default_money_account(current_workspace),
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

    if save_transaction
      @extraction&.update!(review_status: :recorded, recorded_transaction: @transaction)

      if @extraction
        redirect_to document_reviews_path, notice: "Transaction recorded from WhatsApp."
      else
        respond_with_ledger_update
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @transaction.assign_attributes(transaction_params)

    if save_transaction
      respond_with_ledger_update
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Moves a captured draft into the ledger. A missing category or account is filled
  # with a placeholder rather than refused — see Ledger::Poster.
  def post_to_books
    Ledger::Poster.call(@transaction)
    respond_with_ledger_update
  end

  def destroy
    @transaction.destroy
    respond_with_ledger_update
  end

  private
    def set_transaction
      @transaction = current_workspace.transactions.find(params[:id])
    end

    def load_ledger
      @filter = FILTERS.include?(params[:filter]) ? params[:filter] : "all"
      @counts = entry_counts
      @pagy, @transactions = pagy(filtered_entries, limit: PER_PAGE)
      @summary = LedgerSummary.new(current_workspace)
    end

    def filtered_entries
      scope = current_workspace.transactions.includes(:customer, :account).order(occurred_on: :desc, id: :desc)

      case @filter
      when "draft" then scope.drafts
      when "income" then scope.posted.income
      when "expense" then scope.posted.expense
      else scope.posted
      end
    end

    # Totals across every page, so a tab badge never reports just the current page.
    def entry_counts
      by_kind = current_workspace.transactions.posted.group(:kind).count

      {
        "all" => by_kind.values.sum,
        "income" => by_kind["income"] || 0,
        "expense" => by_kind["expense"] || 0,
        "draft" => current_workspace.transactions.drafts.count
      }
    end

    # One stream refreshes every region the ledger can move, so the same response is
    # correct from the dashboard and from the entries list.
    def respond_with_ledger_update
      load_ledger

      respond_to do |format|
        format.turbo_stream { render :ledger_update }
        format.html { redirect_back fallback_location: dashboard_path }
      end
    end

    # "Save for later" keeps the entry out of the ledger; anything else posts it.
    # A draft holds no postings, so it reaches no balance and no total.
    def save_transaction
      if params[:draft].present?
        @transaction.status = :draft
        @transaction.postings.destroy_all if @transaction.persisted?
        @transaction.save
      else
        # The poster fills a missing category or account before saving, so this only
        # fails on something genuinely unpostable — no amount, or no direction.
        Ledger::Poster.call(@transaction)
        true
      end
    rescue ActiveRecord::RecordInvalid
      false
    end

    def transaction_params
      attributes = params.require(:transaction).permit(:kind, :amount, :category, :customer_id, :occurred_on, :description)
      # Resolved through the workspace's own money accounts rather than mass assigned,
      # so a submitted id can never reach another workspace's ledger.
      account_id = params[:transaction][:account_id]
      attributes[:account] = current_workspace.accounts.asset.find_by(id: account_id) if account_id.present?
      attributes
    end
end
