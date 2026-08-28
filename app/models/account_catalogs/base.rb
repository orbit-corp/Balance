module AccountCatalogs
  class Base
    class << self
      def chart_of_accounts
        self::CHART_OF_ACCOUNTS
      end

      def categories
        chart_of_accounts
      end

      def core
        account_specs
      end

      def recommended
        @recommended ||= account_types.each_with_object({}) do |account_type, specs|
          account_type.fetch(:detail_types).each do |detail|
            next if detail.is_a?(Hash) && detail.fetch(:accounts, {}).any?

            name = detail_name(detail)
            role = [ account_type.fetch(:account_type), name ].join(" ").parameterize(separator: "_").to_sym
            specs[role] = {
              name: name,
              base: category_for(account_type.fetch(:account_type)).downcase,
              type: account_type.fetch(:account_type),
              detail: name,
              description: account_type.fetch(:description)
            }
          end
        end.freeze
      end

      def account_spec(role)
        account_specs.fetch(role.to_sym)
      end

      def account_types
        @account_types ||= chart_of_accounts.flat_map { |category| category[:account_types] }
      end

      def find(account_type)
        account_types.find { |entry| entry[:account_type] == account_type }
      end

      def category_for(account_type)
        chart_of_accounts.find do |category|
          category[:account_types].any? do |entry|
            entry[:account_type] == account_type
          end
        end&.fetch(:category)
      end

      def detail_types_for(account_type)
        find(account_type)&.fetch(:detail_types)&.map { |detail| detail_name(detail) }
      end

      def as_hash
        account_types.to_h do |entry|
          [
            entry[:account_type],
            {
              category: category_for(entry[:account_type]),
              detail_types: detail_types_for(entry[:account_type])
            }
          ]
        end
      end

      private

      def account_specs
        @account_specs ||= account_types.each_with_object({}) do |account_type, specs|
          account_type.fetch(:detail_types).each do |detail|
            next unless detail.is_a?(Hash)

            detail.fetch(:accounts, {}).each do |role, account|
              specs[role.to_sym] = account.merge(
                base: category_for(account_type.fetch(:account_type)).downcase,
                type: account_type.fetch(:account_type),
                detail: detail.fetch(:name),
                description: account_type.fetch(:description)
              )
            end
          end
        end.freeze
      end

      def detail_name(detail)
        detail.is_a?(Hash) ? detail.fetch(:name) : detail
      end
    end
  end
end
