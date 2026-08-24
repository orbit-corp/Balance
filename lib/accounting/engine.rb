# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"
require "date"
require "securerandom"

require_relative "behaviour"

module Accounting
  # Proof machine for classified journal entries.
  #
  # Input is an already-classified entry: every line carries its account,
  # base type (one of asset/liability/equity/income/expense), side
  # (debit/credit) and amount. The engine proves that this classification
  # can happen:
  #
  #   1. Direction   - each line's effect follows from its declared base
  #                    type: assets and expenses increase when debited;
  #                    liabilities, equity and income increase when credited.
  #   2. Structure   - valid types, at least two lines, one side per line,
  #                    positive amounts, debits == credits, no account on
  #                    both sides; where an account is registered, its stored
  #                    type must agree with the declared classification.
  #   3. Atomicity   - balances mutate only after all checks pass.
  #   4. Invariant   - Assets + Expenses == Liabilities + Equity + Income,
  #                    checked after apply with full rollback on failure.
  #
  # Contract:
  #   - Engine#check(lines)    -> CheckResult (ok? / errors / proof).
  #                               Validates proposed lines; creates nothing,
  #                               mutates nothing.
  #   - Engine#post_lines(...) -> only after validation passes does it
  #                               create the journal entry and post it to
  #                               the ledger atomically. On any failure the
  #                               ledger is untouched.
  class Engine
    class Error < StandardError; end

    class ValidationError < Error; end

    LineProof = Struct.new(:account_code, :base_type, :side, :effect)

    Proof = Struct.new(:lines, :total_debits, :total_credits) do
      def balanced?
        total_debits == total_credits
      end

      def to_s
        rendered = lines.map do |line_proof|
          "#{line_proof.account_code} [#{line_proof.base_type}] #{line_proof.side} => #{line_proof.effect}"
        end

        "#{rendered.join(' | ')} || debits #{total_debits} / credits #{total_credits}"
      end
    end

    CheckResult = Struct.new(:errors, :lines, :proof) do
      def ok? = errors.empty?
    end

    Account = Struct.new(:code, :name, :base_type) do
      def debit_total = @debit_total ||= BigDecimal("0")

      def credit_total = @credit_total ||= BigDecimal("0")

      def debit(amount)
        @debit_total = debit_total + amount
      end

      def credit(amount)
        @credit_total = credit_total + amount
      end

      def balance
        if Behaviour.debit_normal?(base_type)
          debit_total - credit_total
        else
          credit_total - debit_total
        end
      end
    end

    class EntryLine
      attr_reader :account_code, :base_type, :side, :amount, :memo

      def initialize(account_code:, base_type:, side:, amount:, memo: "")
        raise ArgumentError, "missing account" if account_code.nil?

        Behaviour.normal_balance(base_type)
        @base_type = Behaviour.normalize(base_type)

        raise ArgumentError, "Unknown side: #{side.inspect}" unless Behaviour::SIDES.include?(side)

        amount = BigDecimal(amount.to_s).round(2)
        raise ArgumentError, "Amount must be positive" unless amount.positive?

        @account_code = account_code.to_s
        @side         = side
        @amount       = amount
        @memo         = memo.to_s
      end
    end

    class JournalEntry
      attr_reader :date, :description, :lines, :reverses_entry_id, :entry_id

      def initialize(date:, description:, lines:, reverses_entry_id: nil)
        lines = Array(lines)
        raise ValidationError, "Entry requires at least two lines" if lines.size < 2

        @date               = date.is_a?(Date) ? date : Date.parse(date.to_s)
        @description        = description.to_s
        @lines              = lines.freeze
        @reverses_entry_id  = reverses_entry_id
        @entry_id           = SecureRandom.hex(8)
      end

      def reversal?
        !reverses_entry_id.nil?
      end

      def total(side)
        lines.select { |line| line.side == side }.sum(&:amount)
      end

      def balanced?
        total(:debit) == total(:credit)
      end

      def validate!
        raise ValidationError, "Debits must equal credits" unless balanced?

        both_sides = lines.group_by(&:account_code).select { |_, ls| ls.map(&:side).uniq.size > 1 }
        unless both_sides.empty?
          raise ValidationError, "Account #{both_sides.keys.first} appears on both sides of the entry"
        end
      end
    end

    attr_reader :accounts, :journal

    def initialize
      @accounts = {}
      @journal  = []
    end

    def add_account(code, name, base_type)
      code = code.to_s
      raise ValidationError, "Account #{code} already exists" if accounts.key?(code)

      Behaviour.normal_balance(base_type)
      accounts[code] = Account.new(code, name, Behaviour.normalize(base_type))
    end

    def get_account(code)
      accounts.fetch(code.to_s) { raise ValidationError, "Unknown account: #{code}" }
    end

    # Validates classified lines without creating or posting anything.
    # Accepts EntryLine objects or plain hashes:
    #   { account_code: "1000", base_type: "asset", side: :debit, amount: 250, memo: "optional" }
    # Returns a CheckResult carrying errors and, when every line normalizes,
    # a Proof: the per-line direction verdicts plus entry totals.
    # Never mutates ledger state.
    def check(lines)
      errors   = []
      prepared = []

      Array(lines).each_with_index do |raw, index|
        begin
          prepared << normalize_line(raw)
        rescue StandardError => e
          errors << "Line #{index + 1}: #{e.message}"
        end
      end

      proof = build_proof(prepared) if errors.empty?
      errors.concat(structural_errors(prepared)) if errors.empty?

      CheckResult.new(errors.freeze, prepared.freeze, proof)
    end

    # The gatekeeper entry point: validates first; only on success creates
    # the journal entry and posts it atomically. Raises ValidationError with
    # every reason when invalid, leaving the ledger untouched.
    def post_lines(date:, description:, lines:)
      result = check(lines)
      raise ValidationError, result.errors.join(" ") unless result.ok?

      post(JournalEntry.new(date: date, description: description, lines: result.lines))
    end

    def post(entry)
      entry.validate!

      snapshot = deep_totals
      begin
        apply!(entry)
        raise Error, "Accounting equation violated" unless equation_holds?

        @journal << entry
        entry
      rescue StandardError
        restore(snapshot)
        raise
      end
    end

    def reverse!(posted_entry, date: Date.today, reason: nil)
      raise ValidationError, "Only posted entries can be reversed" unless journal.include?(posted_entry)
      raise ValidationError, "A reversal cannot be reversed" if posted_entry.reversal?

      lines = posted_entry.lines.map do |line|
        EntryLine.new(
          account_code: line.account_code,
          base_type:    line.base_type,
          side:         line.side == :debit ? :credit : :debit,
          amount:       line.amount,
          memo:         reason.to_s
        )
      end

      post(JournalEntry.new(
             date:              date,
             description:       "Reversal of #{posted_entry.entry_id}",
             lines:             lines,
             reverses_entry_id: posted_entry.entry_id
           ))
    end

    def balance(base_type)
      key = Behaviour.normalize(base_type)
      accounts.values.select { |a| a.base_type == key }.sum(&:balance)
    end

    def equation_holds?
      (balance("asset") + balance("expense")) ==
        (balance("liability") + balance("equity") + balance("income"))
    end

    private

    def normalize_line(raw)
      return raw if raw.is_a?(EntryLine)

      attrs = raw.to_h.transform_keys { |k| k.to_sym }
      key   = %i[account_code account code].find { |k| attrs.key?(k) }
      raise ArgumentError, "missing account" unless key

      type_key = %i[base_type type].find { |k| attrs.key?(k) }
      raise ArgumentError, "missing base_type" unless type_key

      EntryLine.new(
        account_code: attrs.fetch(key),
        base_type:    attrs.fetch(type_key),
        side:         attrs.fetch(:side).to_sym,
        amount:       attrs.fetch(:amount),
        memo:         attrs.fetch(:memo, "")
      )
    rescue KeyError => e
      raise ArgumentError, "missing #{e.key}"
    end

    def structural_errors(lines)
      errors = []
      errors << "An entry requires at least two lines" if lines.size < 2

      total_debits  = lines.select { |l| l.side == :debit }.sum(&:amount)
      total_credits = lines.select { |l| l.side == :credit }.sum(&:amount)
      unless total_debits == total_credits
        errors << "Total debits (#{format('%.2f', total_debits)}) must equal total credits (#{format('%.2f', total_credits)})"
      end

      washed = lines.group_by(&:account_code)
                    .select { |_, ls| ls.map(&:side).uniq.size > 1 }
                    .keys
      errors << "Account(s) used on both sides: #{washed.join(', ')}" unless washed.empty?

      unknown = lines.map(&:account_code).uniq.reject { |code| accounts.key?(code) }
      unknown.each { |code| errors << "Unknown account: #{code}" }

      misclassified(lines).each do |account, declared|
        errors << "Account #{account.code} is registered as #{account.base_type.inspect} but the line declares #{declared.inspect}"
      end

      errors
    end

    def misclassified(lines)
      lines.group_by(&:account_code).filter_map do |code, ls|
        account = accounts[code]
        next if account.nil?

        wrong = ls.reject { |l| l.base_type == account.base_type }
        [account, wrong.first.base_type] unless wrong.empty?
      end
    end

    def build_proof(lines)
      Proof.new(
        lines.map do |line|
          LineProof.new(
            line.account_code,
            line.base_type,
            line.side,
            Behaviour.effect(line.base_type, line.side)
          )
        end,
        lines.select { |l| l.side == :debit }.sum(&:amount),
        lines.select { |l| l.side == :credit }.sum(&:amount)
      )
    end

    def apply!(entry)
      entry.lines.each do |line|
        account = get_account(line.account_code)
        account.public_send(line.side, line.amount)
      end
    end

    def deep_totals
      accounts.transform_values do |account|
        [account.debit_total, account.credit_total]
      end
    end

    def restore(snapshot)
      snapshot.each do |code, (debits, credits)|
        account = accounts.fetch(code)
        account.instance_variable_set(:@debit_total, debits)
        account.instance_variable_set(:@credit_total, credits)
      end
    end
  end
end
