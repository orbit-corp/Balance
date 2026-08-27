class JournalEntriesController < ApplicationController
  def index
    @journal_entries = current_workspace.journal_entries
      .includes(journal_entry_lines: :account)
    @journal_entries = @journal_entries.where("description ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%") if params[:q].present?
    @journal_entries = @journal_entries.where(entry_date: parsed_date_range) if parsed_date_range
    @journal_entries = @journal_entries.order(entry_date: :desc, id: :desc)
  end

  def new
    @journal_entry = current_workspace.journal_entries.build
    2.times { @journal_entry.journal_entry_lines.build }
  end

  def create
    @journal_entry = current_workspace.journal_entries.build(journal_entry_params)
    result = Accounting::PostingService.call(entry: @journal_entry)

    if result.success?
      respond_to do |format|
        format.html { redirect_to journal_entries_path, notice: "Journal entry recorded." }
        format.turbo_stream { render turbo_stream: turbo_stream.action(:redirect, journal_entries_path) }
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def parsed_date_range
      return if params[:from].blank? || params[:to].blank?

      Date.iso8601(params[:from])..Date.iso8601(params[:to])
    rescue Date::Error
      nil
    end

    def journal_entry_params
      params.expect(journal_entry: [
        :entry_date, :description,
        journal_entry_lines_attributes: [ [ :id, :account_id, :debit, :credit, :_destroy ] ]
      ])
    end
end
