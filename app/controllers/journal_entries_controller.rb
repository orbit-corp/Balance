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

    if @journal_entry.save
      redirect_to journal_entries_path, notice: "Journal entry recorded."
    else
      flash.now[:alert] = @journal_entry.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private
    def journal_entry_params
      params.require(:journal_entry).permit(
        :entry_date, :description,
        journal_entry_lines_attributes: [ :id, :account_id, :debit, :credit, :_destroy ]
      )
    end
end
