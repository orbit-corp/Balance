class JournalEntriesController < ApplicationController
  def index
    @journal_entries = current_workspace.journal_entries
      .includes(journal_entry_lines: :account)
      .order(entry_date: :desc, id: :desc)
  end

  def new
    @journal_entry = current_workspace.journal_entries.build
    2.times { @journal_entry.journal_entry_lines.build }
  end

  def create
    @journal_entry = current_workspace.journal_entries.build(journal_entry_params)
    result = Accounting::PostingService.call(entry: @journal_entry)

    if result.success?
      redirect_to journal_entries_path, notice: "Journal entry recorded."
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def journal_entry_params
      params.expect(journal_entry: [
        :entry_date, :description,
        journal_entry_lines_attributes: [ [ :id, :account_id, :debit, :credit, :_destroy ] ]
      ])
    end
end
