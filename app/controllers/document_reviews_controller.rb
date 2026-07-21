# Review queue for the vision layer: bank-transfer documents extracted from WhatsApp
# attachments that the user hasn't yet turned into a ledger transaction (or dismissed).
# Recording itself flows through TransactionsController#create — this controller only
# lists pending items and lets the user dismiss ones they don't want.
class DocumentReviewsController < ApplicationController
  def index
    @extractions = current_workspace.whatsapp_document_extractions
                                    .awaiting_review
                                    .includes(:whatsapp_message)
                                    .order(created_at: :desc)
  end

  def dismiss
    extraction = current_workspace.whatsapp_document_extractions.find(params[:id])
    extraction.review_dismissed!
    redirect_to document_reviews_path, notice: "Document dismissed."
  end
end
