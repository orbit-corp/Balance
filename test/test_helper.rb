ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Creates an entry and puts it in the ledger. Totals and balances read postings,
    # so a test that wants to see a figure move has to post, not just create.
    def post_transaction!(workspace, **attributes)
      Ledger::ChartOfAccounts.seed!(workspace)
      Ledger::Poster.call(workspace.transactions.create!(status: :draft, **attributes))
    end
  end
end
