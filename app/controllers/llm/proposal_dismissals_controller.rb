class Llm::ProposalDismissalsController < Llm::ProposalActionsController
  def update
    @proposal.dismiss! if @proposal.pending?
    respond_with_card
  end
end
