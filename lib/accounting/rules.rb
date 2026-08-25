# frozen_string_literal: true

module Accounting
  module Rules
    # The debit and credit effects are derived from each account's base type.
    # These are the four lawful relationships possible without transaction intent.
    RELATIONSHIPS = {
      increase: { increase: :expansion, decrease: :reallocation },
      decrease: { increase: :reallocation, decrease: :contraction }
    }.freeze

    def self.relationship_for(debit:, credit:)
      RELATIONSHIPS.dig(debit.effect, credit.effect)
    end
  end
end
