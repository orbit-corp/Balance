module Ledger
  # Moves a transaction into the general ledger by writing its postings. This is
  # the only place postings are created, and it refuses to leave behind an
  # unbalanced entry.
  #
  # Posting never blocks on a missing category or account — it fills a placeholder
  # instead. An uncategorised expense still gives a correct profit and a correct
  # balance; an unposted one gives neither.
  class Poster
    class UnbalancedError < StandardError; end

    def self.call(transaction) = new(transaction).call

    def initialize(transaction)
      @transaction = transaction
    end

    def call
      Transaction.transaction do
        apply_placeholders
        transaction.status = :posted
        transaction.save!

        transaction.postings.destroy_all
        entries.each { |account, amount_kobo| transaction.postings.create!(account: account, amount_kobo: amount_kobo) }

        raise UnbalancedError, "postings for transaction #{transaction.id} do not sum to zero" unless transaction.postings.reload.sum(:amount_kobo).zero?
      end

      transaction
    end

    private
      attr_reader :transaction

      def apply_placeholders
        transaction.category = ChartOfAccounts::UNCATEGORISED if transaction.category.blank?
        transaction.account ||= ChartOfAccounts.default_money_account(transaction.workspace)
      end

      # Money in: the account it landed in is debited, the income category credited.
      # Money out: the expense category is debited, the account it left credited.
      def entries
        amount = transaction.amount_kobo
        category = ChartOfAccounts.category_account(transaction.workspace, transaction.kind, transaction.category)

        if transaction.income?
          [ [ transaction.account, amount ], [ category, -amount ] ]
        else
          [ [ category, amount ], [ transaction.account, -amount ] ]
        end
      end
  end
end
