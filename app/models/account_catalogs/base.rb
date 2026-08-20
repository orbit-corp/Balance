module AccountCatalogs
  class Base
    class << self
      def chart_of_accounts
        self::CHART_OF_ACCOUNTS
      end

      def categories
        chart_of_accounts
      end

      def account_types
        @account_types ||= categories.flat_map { |category| category[:account_types] }
      end

      def find(account_type)
        account_types.find { |entry| entry[:account_type] == account_type }
      end

      def category_for(account_type)
        categories.find do |category|
          category[:account_types].any? do |entry|
            entry[:account_type] == account_type
          end
        end&.fetch(:category)
      end

      def detail_types_for(account_type)
        find(account_type)&.fetch(:detail_types)
      end

      def as_hash
        account_types.to_h do |entry|
          [
            entry[:account_type],
            {
              category: category_for(entry[:account_type]),
              detail_types: entry[:detail_types]
            }
          ]
        end
      end
    end
  end
end
