# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../../lib/accounting/engine"

module Accounting
  class EngineTest < Minitest::Test
    Account = Data.define(:id, :name, :base_type)
    ModelLine = Data.define(:account, :debit_kobo, :credit_kobo)

    def setup
      @cash = account("cash", "Cash", "asset")
      @bank = account("bank", "Bank", "asset")
      @payable = account("payable", "Accounts Payable", "liability")
      @income = account("income", "Income", "income")
      @expense = account("expense", "Expense", "expense")
    end

    def test_derives_effects_from_account_base_types
      result = check(line(@cash, :debit, 10_000), line(@income, :credit, 10_000))

      assert result.ok?, result.errors.join(" ")
      assert_equal %i[increase increase], result.lines.map(&:effect)
      assert_equal :expansion, result.proof.relationships.first.law
    end

    def test_recognizes_reallocation_between_debit_normal_accounts
      result = check(line(@cash, :debit, 10_000), line(@bank, :credit, 10_000))

      assert result.ok?
      assert_equal %i[increase decrease], result.lines.map(&:effect)
      assert_equal :reallocation, result.proof.relationships.first.law
    end

    def test_recognizes_reallocation_between_credit_normal_accounts
      result = check(line(@payable, :debit, 10_000), line(@income, :credit, 10_000))

      assert result.ok?
      assert_equal %i[decrease increase], result.lines.map(&:effect)
      assert_equal :reallocation, result.proof.relationships.first.law
    end

    def test_recognizes_contraction
      result = check(line(@payable, :debit, 10_000), line(@cash, :credit, 10_000))

      assert result.ok?
      assert_equal %i[decrease decrease], result.lines.map(&:effect)
      assert_equal :contraction, result.proof.relationships.first.law
    end

    def test_rejects_a_relationship_missing_from_the_rules_matrix
      rejecting_rules = Object.new
      def rejecting_rules.relationship_for(debit:, credit:) = nil

      result = Engine.check(
        [ line(@cash, :debit, 10_000), line(@income, :credit, 10_000) ],
        rules: rejecting_rules
      )

      refute result.ok?
      assert_includes result.errors, "Cash cannot be debited against Income"
    end

    def test_rejects_unbalanced_entries
      result = check(line(@expense, :debit, 10_000), line(@cash, :credit, 9_000))

      refute result.ok?
      assert_includes result.errors, "Total debits (100.00) must equal total credits (90.00)"
    end

    def test_rejects_an_account_used_on_both_sides
      result = check(line(@cash, :debit, 10_000), line(@cash, :credit, 10_000))

      refute result.ok?
      assert_includes result.errors, "Account(s) used on both sides: cash"
    end

    def test_rejects_duplicate_lines
      result = check(
        line(@expense, :debit, 5_000),
        line(@expense, :debit, 5_000),
        line(@cash, :credit, 10_000)
      )

      refute result.ok?
      assert_includes result.errors, "duplicate journal lines are not allowed"
    end

    def test_rejects_single_line_entries
      result = check(line(@cash, :debit, 10_000))

      refute result.ok?
      assert_includes result.errors, "An entry requires at least two lines"
    end

    def test_reports_invalid_lines_without_a_proof
      result = check(
        { side: :debit, amount_kobo: 10_000 },
        line(@cash, :sideways, 10_000),
        line(@cash, :credit, 0)
      )

      refute result.ok?
      assert_nil result.proof
      assert_match(/Line 1: missing account/, result.errors[0])
      assert_match(/Line 2: Unknown side/, result.errors[1])
      assert_match(/Line 3: Amount must be a positive whole number of kobo/, result.errors[2])
    end

    def test_rejects_unknown_account_base_types
      crypto = account("crypto", "Crypto", "crypto")
      result = check(line(crypto, :debit, 10_000), line(@cash, :credit, 10_000))

      refute result.ok?
      assert_match(/Line 1: Unknown base type/, result.errors.first)
    end

    def test_accepts_model_lines_and_derives_their_sides
      result = Engine.check([
        ModelLine.new(@expense, 25_000, 0),
        ModelLine.new(@cash, 0, 25_000)
      ])

      assert result.ok?, result.errors.join(" ")
      assert_equal %i[debit credit], result.lines.map(&:side)
      assert_equal 25_000, result.proof.total_debits_kobo
      assert result.proof.balanced?
    end

    def test_rejects_model_lines_with_both_sides
      result = Engine.check([
        ModelLine.new(@expense, 25_000, 25_000),
        ModelLine.new(@cash, 0, 25_000)
      ])

      refute result.ok?
      assert_match(/either a debit or a credit/, result.errors.first)
    end

    def test_has_no_persistence_api
      refute_respond_to Engine.new([]), :post
      refute_respond_to Engine.new([]), :post_lines
      refute_respond_to Engine.new([]), :journal
    end

    private

    def account(id, name, base_type)
      Account.new(id, name, base_type)
    end

    def line(account, side, amount_kobo)
      { account: account, side: side, amount_kobo: amount_kobo }
    end

    def check(*lines)
      Engine.check(lines)
    end
  end
end
