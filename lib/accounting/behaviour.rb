# frozen_string_literal: true

module Accounting
  # Intrinsic account behaviour: what posting on a side does to an account.
  #
  # This is the primitive of the engine. Every legality rule derives from it;
  # nothing else in the engine hardcodes accounting knowledge about types.
  module Behaviour
    NORMAL_BALANCE = {
      "asset"     => :debit,
      "expense"   => :debit,
      "liability" => :credit,
      "equity"    => :credit,
      "income"    => :credit
    }.freeze

    BASE_TYPES = NORMAL_BALANCE.keys.freeze

    SIDES = %i[debit credit].freeze

    class << self
      def normal_balance(base_type)
        NORMAL_BALANCE.fetch(normalize(base_type)) do
          raise ArgumentError, "Unknown base type: #{base_type.inspect} (known: #{BASE_TYPES.join(', ')})"
        end
      end

      def effect(base_type, side)
        raise ArgumentError, "Unknown side: #{side.inspect}" unless SIDES.include?(side)

        normal_balance(base_type) == side ? :increase : :decrease
      end

      def debit_normal?(base_type)
        normal_balance(base_type) == :debit
      end

      def normalize(base_type)
        base_type.to_s.downcase.strip
      end
    end
  end
end
