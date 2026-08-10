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
