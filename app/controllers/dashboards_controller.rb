class DashboardsController < ApplicationController
  def show
    @summary = LedgerSummary.new(current_workspace)
  end
end
