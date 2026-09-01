class Llm::ProposalsController < Llm::ProposalActionsController
  def update
    return respond_with_card unless @proposal.journal_entry_proposal?
    return respond_with_card unless @proposal.pending?
    return respond_with_card if @proposal.reversal_proposal?

    return respond_with_card(draft.errors) if draft.invalid?

    @proposal.update!(data: draft.data)
    respond_with_card
  end

  private
    def proposal_params
      params.expect(proposal: [ :description, :entry_date, :reverses_journal_entry_id, lines: [ [ :account_id, :side, :amount_naira, :counterparty_name ] ] ])
    end

    def draft
      @draft ||= if @proposal.reversal_proposal?
        Llm::JournalEntryProposal.new(workspace: current_workspace, data: @proposal.data)
      else
        Llm::JournalEntryProposal.from_form(workspace: current_workspace, params: proposal_params)
      end
    end
end
