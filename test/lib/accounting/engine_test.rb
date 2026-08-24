# frozen_string_literal: true

require "minitest/autorun"
require "date"

require_relative "../../../lib/accounting/engine"

module Accounting
  class EngineTest < Minitest::Test
    def self.test(description, &block)
      name = "test_#{description.gsub(/[^a-z0-9]+/i, "_").downcase.sub(/_$/, "")}"
      define_method(name, &block)
    end

    def setup
      @engine = Accounting::Engine.new
      @engine.add_account("1000", "Cash", "asset")
      @engine.add_account("1100", "Bank Account", "asset")
      @engine.add_account("1200", "Pension RSA", "asset")
      @engine.add_account("2000", "Accounts Payable", "liability")
      @engine.add_account("3000", "Owner's Equity", "equity")
      @engine.add_account("4000", "Sales", "income")
      @engine.add_account("4500", "Salary Income", "income")
      @engine.add_account("5000", "Rent Expense", "expense")
      @engine.add_account("5500", "Tax Withheld", "expense")

      @engine.post(entry([
        line("1000", :debit, 1000, "asset"),
        line("3000", :credit, 1000, "equity")
      ]))
    end

    test "posting a classified entry updates balances" do
      posted = post_rent(250)

      assert_includes @engine.journal, posted
      assert_equal BigDecimal("750"), @engine.balance("asset")
      assert_equal BigDecimal("250"), @engine.balance("expense")
      assert @engine.equation_holds?
    end

    test "proves the Example 11 classification can happen" do
      result = salary_entry_check

      assert result.ok?, result.errors.join(" ")
      proof = result.proof

      assert proof.balanced?
      assert_equal BigDecimal("300000"), proof.total_debits
      assert_equal BigDecimal("300000"), proof.total_credits

      effects = { "1100" => :increase, "1200" => :increase, "5500" => :increase, "4500" => :increase }
      proof.lines.each do |line_proof|
        assert_equal effects[line_proof.account_code], line_proof.effect,
          "#{line_proof.account_code} [#{line_proof.base_type}] #{line_proof.side}"
      end
      assert_equal %i[increase increase increase increase], proof.lines.map(&:effect)
    end

    test "assets increase on debit and decrease on credit" do
      incoming = @engine.check([
        hash_line("1100", :debit, 500, "asset"),
        hash_line("4000", :credit, 500, "income")
      ])
      outgoing = @engine.check([
        hash_line("5000", :debit, 500, "expense"),
        hash_line("1100", :credit, 500, "asset")
      ])

      assert_equal :increase, incoming.proof.lines.first.effect
      assert_equal :decrease, outgoing.proof.lines.last.effect
    end

    test "liabilities equity and income increase on credit" do
      result = @engine.check([
        hash_line("1000", :debit, 100, "asset"),
        hash_line("2000", :credit, 40, "liability"),
        hash_line("3000", :credit, 30, "equity"),
        hash_line("4000", :credit, 30, "income")
      ])

      assert result.ok?, result.errors.join(" ")
      credit_effects = result.proof.lines.select { |l| l.side == :credit }.map(&:effect)

      assert_equal %i[increase increase increase], credit_effects
    end

    test "rejects unclassified lines" do
      result = @engine.check([
        { account_code: "5000", side: :debit, amount: 25 },
        { account_code: "1000", side: :credit, amount: 25 }
      ])

      refute result.ok?
      assert_match(/Line 1: missing base_type/, result.errors.join)
    end

    test "rejects unknown base types on lines" do
      assert_raises(ArgumentError) { line("5000", :debit, 25, "crypto") }

      result = @engine.check([
        { account_code: "5000", base_type: "crypto", side: :debit, amount: 25 },
        { account_code: "1000", base_type: "asset", side: :credit, amount: 25 }
      ])

      refute result.ok?
      assert_match(/Line 1: Unknown base type/, result.errors.join)
    end

    test "rejects misclassified lines against registered accounts" do
      result = @engine.check([
        hash_line("1000", :debit, 50, "expense"),
        hash_line("3000", :credit, 50, "equity")
      ])

      refute result.ok?
      assert_match(/Account 1000 is registered as "asset" but the line declares "expense"/, result.errors.join)
    end

    test "rejects unbalanced entries without mutating balances" do
      assert_raises(Accounting::Engine::ValidationError) do
        @engine.post(entry([
          line("5000", :debit, 250, "expense"),
          line("1000", :credit, 200, "asset")
        ]))
      end

      assert_equal BigDecimal("1000"), @engine.balance("asset")
      assert_equal BigDecimal("0"), @engine.balance("expense")
    end

    test "rejects single-line entries" do
      assert_raises(Accounting::Engine::ValidationError) do
        @engine.post(entry([line("5000", :debit, 250, "expense")]))
      end
    end

    test "rejects lines with non-positive amounts" do
      assert_raises(ArgumentError) { line("5000", :debit, 0, "expense") }
      assert_raises(ArgumentError) { line("5000", :debit, -5, "expense") }
    end

    test "rejects the same account on both sides" do
      assert_raises(Accounting::Engine::ValidationError) do
        @engine.post(entry([
          line("1000", :debit, 100, "asset"),
          line("1000", :credit, 100, "asset")
        ]))
      end
    end

    test "unknown account is rejected" do
      assert_raises(Accounting::Engine::ValidationError) do
        @engine.post(entry([
          line("9999", :debit, 100, "asset"),
          line("1000", :credit, 100, "asset")
        ]))
      end
    end

    test "unknown base type is rejected when adding an account" do
      assert_raises(ArgumentError) { @engine.add_account("6000", "Crypto Wallet", "crypto") }
    end

    test "reverse flips sides links and restores balances" do
      original = post_rent(250)
      journal_size = @engine.journal.size
      reversal = @engine.reverse!(original)

      assert_equal original.entry_id, reversal.reverses_entry_id
      assert_equal journal_size + 1, @engine.journal.size
      assert_equal BigDecimal("1000"), @engine.balance("asset")
      assert_equal BigDecimal("0"), @engine.balance("expense")
      assert @engine.equation_holds?
    end

    test "a reversal cannot be reversed" do
      original = post_rent(250)
      reversal = @engine.reverse!(original)

      assert_raises(Accounting::Engine::ValidationError) { @engine.reverse!(reversal) }
    end

    test "an unposted entry cannot be reversed" do
      unposted = entry([line("5000", :debit, 10, "expense"), line("1000", :credit, 10, "asset")])

      assert_raises(Accounting::Engine::ValidationError) { @engine.reverse!(unposted) }
    end

    test "the equation detects tampering" do
      assert @engine.equation_holds?
      @engine.get_account("3000").credit(BigDecimal("500"))
      refute @engine.equation_holds?
    end

    test "check accepts raw hash lines and reports proof" do
      result = @engine.check([
        { account_code: "5000", base_type: "expense", side: :debit, amount: 25 },
        { account_code: "1000", base_type: "asset", side: :credit, amount: 25 }
      ])

      assert result.ok?
      assert_empty result.errors
      assert_equal 2, result.lines.size
      assert_equal %w[expense asset], result.proof.lines.map(&:base_type)
      assert_equal %i[increase decrease], result.proof.lines.map(&:effect)
      assert result.proof.balanced?
      assert_includes result.proof.to_s, "5000 [expense] debit => increase"
    end

    test "check reports line construction problems as precise errors" do
      result = @engine.check([
        { account_code: "5000", base_type: "expense", side: :debit, amount: 0 },
        { account_code: "1000" }
      ])

      refute result.ok?
      assert_match(/Line 1: Amount must be positive/, result.errors[0])
      assert_match(/Line 2: missing base_type/, result.errors[1])
    end

    test "check collects all structural errors at once" do
      result = @engine.check([
        { account_code: "9999", base_type: "asset", side: :debit, amount: 10 },
        { account_code: "1000", base_type: "asset", side: :credit, amount: 5 }
      ])

      refute result.ok?
      joined = result.errors.join(" | ")
      assert_match(/Total debits \(10\.00\) must equal total credits \(5\.00\)/, joined)
      assert_match(/Unknown account: 9999/, joined)
    end

    test "check mutates nothing" do
      journal_size = @engine.journal.size

      salary_entry_check

      assert_equal journal_size, @engine.journal.size
      assert_equal BigDecimal("1000"), @engine.balance("asset")
    end

    test "post_lines creates and posts atomically when valid" do
      posted = @engine.post_lines(
        date: Date.new(2026, 8, 21),
        description: "Cash sale",
        lines: [
          { account_code: "1000", base_type: "asset", side: :debit, amount: 120 },
          { account_code: "4000", base_type: "income", side: :credit, amount: 120 }
        ]
      )

      assert_includes @engine.journal, posted
      assert_equal BigDecimal("1120"), @engine.balance("asset")
      assert_equal BigDecimal("120"), @engine.balance("income")
      assert @engine.equation_holds?
    end

    test "post_lines never creates or posts anything when invalid" do
      journal_size = @engine.journal.size
      totals_before = deep_totals_snapshot

      assert_raises(Accounting::Engine::ValidationError) do
        @engine.post_lines(
          date: Date.new(2026, 8, 21),
          description: "Broken entry",
          lines: [
            { account_code: "3000", base_type: "equity", side: :debit, amount: 50 },
            { account_code: "5000", base_type: "expense", side: :credit, amount: 45 }
          ]
        )
      end

      assert_equal journal_size, @engine.journal.size
      assert_equal totals_before, deep_totals_snapshot
    end

    private

    def deep_totals_snapshot
      @engine.accounts.transform_values { |a| [a.debit_total, a.credit_total] }
    end

    def salary_entry_check
      @engine.check([
        hash_line("1100", :debit, 250_000, "asset"),
        hash_line("1200", :debit, 30_000, "asset"),
        hash_line("5500", :debit, 20_000, "expense"),
        hash_line("4500", :credit, 300_000, "income")
      ])
    end

    def post_rent(amount)
      @engine.post(entry([
        line("5000", :debit, amount, "expense"),
        line("1000", :credit, amount, "asset")
      ]))
    end

    def line(account_code, side, amount, base_type)
      Accounting::Engine::EntryLine.new(
        account_code: account_code, side: side, amount: amount, base_type: base_type
      )
    end

    def hash_line(account_code, side, amount, base_type)
      { account_code: account_code, side: side, amount: amount, base_type: base_type }
    end

    def entry(lines)
      Accounting::Engine::JournalEntry.new(
        date: Date.new(2026, 8, 21),
        description: "Test entry",
        lines: lines
      )
    end
  end
end
