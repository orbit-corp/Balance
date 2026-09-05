# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../../lib/accounting/engine"

module Accounting
  class EngineTest < Minitest::Test
    Account = Data.define(:id, :name, :base_type)
    ModelLine = Data.define(:account, :debit_kobo, :credit_kobo)

    def self.test(description, &block)
      name = "test_#{description.gsub(/[^a-z0-9]+/i, "_").downcase.sub(/_$/, "")}"
      define_method(name, &block)
    end

    def setup
      @cash = account("cash", "Cash", "asset")
      @bank = account("bank", "Bank", "asset")
      @payable = account("payable", "Accounts Payable", "liability")
      @income = account("income", "Income", "income")
      @expense = account("expense", "Expense", "expense")
    end

    test "derives effects from account base types" do
      result = check(line(@cash, :debit, 10_000), line(@income, :credit, 10_000))

      assert result.ok?, result.errors.join(" ")
      assert_equal %i[increase increase], result.lines.map(&:effect)
      assert_equal :expansion, result.proof.relationships.first.law
    end

    test "recognizes reallocation between debit-normal accounts" do
      result = check(line(@cash, :debit, 10_000), line(@bank, :credit, 10_000))

      assert result.ok?
      assert_equal %i[increase decrease], result.lines.map(&:effect)
      assert_equal :reallocation, result.proof.relationships.first.law
    end

    test "recognizes reallocation between credit-normal accounts" do
      result = check(line(@payable, :debit, 10_000), line(@income, :credit, 10_000))

      assert result.ok?
      assert_equal %i[decrease increase], result.lines.map(&:effect)
      assert_equal :reallocation, result.proof.relationships.first.law
    end

    test "recognizes contraction" do
      result = check(line(@payable, :debit, 10_000), line(@cash, :credit, 10_000))

      assert result.ok?
      assert_equal %i[decrease decrease], result.lines.map(&:effect)
      assert_equal :contraction, result.proof.relationships.first.law
    end

    test "rejects a relationship missing from the rules matrix" do
      rejecting_rules = Object.new
      def rejecting_rules.relationship_for(debit:, credit:) = nil

      result = Engine.check(
        [ line(@cash, :debit, 10_000), line(@income, :credit, 10_000) ],
        rules: rejecting_rules
      )

      refute result.ok?
      assert_includes result.errors, "Cash cannot be debited against Income"
    end

    test "rejects unbalanced entries" do
      result = check(line(@expense, :debit, 10_000), line(@cash, :credit, 9_000))

      refute result.ok?
      assert_includes result.errors, "Total debits (100.00) must equal total credits (90.00)"
    end

    test "rejects an account used on both sides" do
      result = check(line(@cash, :debit, 10_000), line(@cash, :credit, 10_000))

      refute result.ok?
      assert_includes result.errors, "Account(s) used on both sides: cash"
    end

    test "rejects duplicate lines" do
      result = check(
        line(@expense, :debit, 5_000),
        line(@expense, :debit, 5_000),
        line(@cash, :credit, 10_000)
      )

      refute result.ok?
      assert_includes result.errors, "duplicate journal lines are not allowed"
    end

    test "rejects single-line entries" do
      result = check(line(@cash, :debit, 10_000))

      refute result.ok?
      assert_includes result.errors, "An entry requires at least two lines"
    end

    test "reports invalid lines without a proof" do
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

    test "rejects unknown account base types" do
      crypto = account("crypto", "Crypto", "crypto")
      result = check(line(crypto, :debit, 10_000), line(@cash, :credit, 10_000))

      refute result.ok?
      assert_match(/Line 1: Unknown base type/, result.errors.first)
    end

    test "accepts model lines and derives their sides" do
      result = Engine.check([
        ModelLine.new(@expense, 25_000, 0),
        ModelLine.new(@cash, 0, 25_000)
      ])

      assert result.ok?, result.errors.join(" ")
      assert_equal %i[debit credit], result.lines.map(&:side)
      assert_equal 25_000, result.proof.total_debits_kobo
      assert result.proof.balanced?
    end

    test "rejects model lines with both sides" do
      result = Engine.check([
        ModelLine.new(@expense, 25_000, 25_000),
        ModelLine.new(@cash, 0, 25_000)
      ])

      refute result.ok?
      assert_match(/either a debit or a credit/, result.errors.first)
    end

    test "rejects malformed model-line amounts" do
      result = Engine.check([
        ModelLine.new(@expense, "3ooo", 0),
        ModelLine.new(@cash, 0, 3_000)
      ])

      refute result.ok?
      assert_match(/amount must be numbers/, result.errors.first)
    end

    test "has no persistence API" do
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
