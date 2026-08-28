# frozen_string_literal: true

require "minitest/autorun"
require "date"
require "bigdecimal"

require_relative "../../../lib/accounting/engine"

# Locks lib/accounting to lib/benchmark/harness/journal_entry_examples.md.
#
# Every documented example is expressed as the classified input the engine
# receives ({account, base_type, side, amount}) together with the direction
# verdict asserted by the doc's "Why" column. Each example must prove its
# classification (check) and preserve Assets + Expenses =
# Liabilities + Equity + Income (post).
class ExamplesConformanceTest < Minitest::Test
  Account = Data.define(:id, :name, :base_type)

  def self.test(description, &block)
    name = "test_#{description.gsub(/[^a-z0-9]+/i, "_").downcase.sub(/_$/, "")}"
    define_method(name, &block)
  end

  # [account, base_type, side, amount, expected_effect]
  EXAMPLES = {
    1 => [ "Cash sale", [
      %w[CASH asset debit 2000 increase],
      %w[SALES income credit 2000 increase]
    ] ],
    2 => [ "Credit sale", [
      %w[AR asset debit 2000 increase],
      %w[SALES income credit 2000 increase]
    ] ],
    3 => [ "Customer pays a prior credit sale", [
      %w[CASH asset debit 2000 increase],
      %w[AR asset credit 2000 decrease]
    ] ],
    4 => [ "Purchase on credit", [
      %w[INV asset debit 20000 increase],
      %w[AP liability credit 20000 increase]
    ] ],
    5 => [ "Cash expense", [
      %w[RENT expense debit 5000 increase],
      %w[CASH asset credit 5000 decrease]
    ] ],
    6 => [ "Paying off a prior credit purchase", [
      %w[AP liability debit 20000 decrease],
      %w[CASH asset credit 20000 decrease]
    ] ],
    7 => [ "Owner deposits personal cash into the business", [
      %w[CASH asset debit 100000 increase],
      %w[EQUITY equity credit 100000 increase]
    ] ],
    8 => [ "Gift of cash with no expectation of repayment", [
      %w[GIFTS expense debit 10000 increase],
      %w[CASH asset credit 10000 decrease]
    ] ],
    9 => [ "Personal loan given, expected to be repaid", [
      %w[LOANS asset debit 10000 increase],
      %w[CASH asset credit 10000 decrease]
    ] ],
    10 => [ "POS agent withdrawal with fee", [
      %w[CASH asset debit 20000 increase],
      %w[CHARGES expense debit 100 increase],
      %w[BANK asset credit 20100 decrease]
    ] ],
    11 => [ "Salary with pension and tax deducted", [
      %w[BANK asset debit 250000 increase],
      %w[RSA asset debit 30000 increase],
      %w[TAX expense debit 20000 increase],
      %w[SALARY income credit 300000 increase]
    ] ],
    12 => [ "Fuel and transport paid together", [
      %w[FUEL expense debit 15000 increase],
      %w[TRANSPORT expense debit 5000 increase],
      %w[CASH asset credit 20000 decrease]
    ] ],
    13 => [ "Ajo/Esusu contribution paid in", [
      %w[AJO asset debit 10000 increase],
      %w[CASH asset credit 10000 decrease]
    ] ],
    14 => [ "Ajo/Esusu payout received", [
      %w[CASH asset debit 120000 increase],
      %w[AJO asset credit 100000 decrease],
      %w[GAIN income credit 20000 increase]
    ] ],
    15 => [ "Phone bought on installment", [
      %w[PHONE asset debit 200000 increase],
      %w[CASH asset credit 50000 decrease],
      %w[AP liability credit 150000 increase]
    ] ],
    16 => [ "Sending money for family support and personal upkeep", [
      %w[FAMILY expense debit 30000 increase],
      %w[UPKEEP expense debit 20000 increase],
      %w[BANK asset credit 50000 decrease]
    ] ],
    17 => [ "Importing goods in USD with an exchange rate move", [
      [                                             # goods received
        %w[INV asset debit 1500000 increase],
        %w[APU liability credit 1500000 increase]
      ],
      [                                             # freight and customs paid
        %w[INV asset debit 80000 increase],
        %w[CASH asset credit 80000 decrease]
      ],
      [                                             # supplier paid at new rate
        %w[APU liability debit 1500000 decrease],
        %w[FX expense debit 50000 increase],
        %w[CASH asset credit 1550000 decrease]
      ]
    ] ]
  }.freeze

  def setup
    @accounts = {
      "CASH"    => "asset",      "BANK"     => "asset",
      "AR"      => "asset",      "INV"      => "asset",
      "RSA"     => "asset",      "LOANS"    => "asset",
      "AJO"     => "asset",      "PHONE"    => "asset",
      "AP"      => "liability",  "APU"      => "liability",
      "EQUITY"  => "equity",
      "SALES"   => "income",     "SALARY"   => "income",
      "GAIN"    => "income",
      "RENT"    => "expense",    "GIFTS"    => "expense",
      "CHARGES" => "expense",    "TAX"      => "expense",
      "FUEL"    => "expense",    "TRANSPORT" => "expense",
      "FAMILY"  => "expense",    "UPKEEP"   => "expense",
      "FX"      => "expense"
    }.to_h { |code, type| [ code, Account.new(code, code.tr("_", " ").capitalize, type) ] }
  end

  test "every documented example proves its classification" do
    EXAMPLES.each do |number, (description, raw)|
      entries = entries_for(raw)

      entries.each_with_index do |lines, index|
        result = Accounting::Engine.check(classified_lines(lines))
        label = entry_label(number, description, index, entries.size)

        assert result.ok?, "#{label} rejected: #{result.errors.join(' ')}"
        assert result.proof.balanced?, "#{label} is unbalanced"

        lines.zip(result.proof.lines).each do |(code, type, side, _amount, effect), proof_line|
          assert_equal code, proof_line.account_id, label
          assert_equal type, proof_line.base_type, "#{label}, line #{code}"
          assert_equal side, proof_line.side.to_s, "#{label}, line #{code}"
          assert_equal effect.to_sym, proof_line.effect,
            "#{label}: #{code} must #{effect} on #{side}"
        end

        debit_count = result.proof.lines.count { |line| line.side == :debit }
        credit_count = result.proof.lines.count { |line| line.side == :credit }
        assert_equal debit_count * credit_count, result.proof.relationships.size,
          "#{label} should prove each debit/credit relationship"
      end
    end
  end

  private

  def entries_for(raw)
    raw.first.first.is_a?(Array) ? raw : [ raw ]
  end

  def entry_label(number, description, index, total)
    label = "Example #{number} (#{description})"
    total > 1 ? "#{label}, entry #{index + 1}" : label
  end

  private

  def classified_lines(lines)
    lines.map do |code, type, side, amount|
      { account: @accounts.fetch(code), side: side.to_sym, amount_kobo: Integer(amount) }
    end
  end
end
