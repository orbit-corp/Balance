# frozen_string_literal: true

require_relative "behaviour"
require_relative "rules"

module Accounting
  # Validates journal lines and proves their directional accounting effects.
  # It has no persistence or balance-owning responsibilities.
  class Engine
    Line = Data.define(:account, :side, :amount_kobo, :effect) do
      def account_id = account.id
      def account_name = account.name
      def base_type = Behaviour.normalize(account.base_type)
    end

    RelationshipProof = Data.define(:debit_account_id, :credit_account_id, :law)

    Proof = Data.define(:lines, :relationships, :total_debits_kobo, :total_credits_kobo) do
      def balanced? = total_debits_kobo == total_credits_kobo
    end

    Result = Data.define(:errors, :lines, :proof) do
      def ok? = errors.empty?
    end

    def self.check(lines, rules: Rules)
      new(lines, rules: rules).check
    end

    def initialize(lines, rules: Rules)
      @raw_lines = Array(lines)
      @rules = rules
    end

    def check
      errors, lines = normalize_lines
      return Result.new(errors.freeze, lines.freeze, nil) if errors.any?

      errors.concat(structural_errors(lines))
      relationships, relationship_errors = check_relationships(lines)
      errors.concat(relationship_errors)

      Result.new(errors.freeze, lines.freeze, build_proof(lines, relationships))
    end

    private

    attr_reader :raw_lines, :rules

    def normalize_lines
      errors = []
      lines = []

      raw_lines.each_with_index do |raw, index|
        lines << normalize_line(raw)
      rescue ArgumentError, KeyError, TypeError => error
        errors << "Line #{index + 1}: #{error.message}"
      end

      [ errors, lines ]
    end

    def normalize_line(raw)
      attributes = attributes_for(raw)
      account = attributes[:account]
      raise ArgumentError, "missing account" if account.nil?
      unless %i[id name base_type].all? { |method| account.respond_to?(method) }
        raise ArgumentError, "account must provide id, name, and base_type"
      end
      raise ArgumentError, "account must be persisted" if account.id.nil?

      base_type = Behaviour.normalize(account.base_type)
      Behaviour.normal_balance(base_type)

      raise ArgumentError, "missing side" if attributes[:side].nil?

      side = attributes[:side].to_s.to_sym
      raise ArgumentError, "Unknown side: #{side.inspect}" unless Behaviour::SIDES.include?(side)

      amount = attributes[:amount_kobo]
      raise ArgumentError, "missing amount_kobo" if amount.nil?

      amount_kobo = amount.is_a?(Integer) ? amount : Integer(amount, 10)
      raise ArgumentError, "Amount must be a positive whole number of kobo" unless amount_kobo.positive?

      Line.new(account, side, amount_kobo, Behaviour.effect(base_type, side))
    end

    def attributes_for(raw)
      return raw.to_h.transform_keys(&:to_sym) if raw.is_a?(Hash)

      unless %i[account debit_kobo credit_kobo].all? { |method| raw.respond_to?(method) }
        raise ArgumentError, "line must provide account, debit_kobo, and credit_kobo"
      end

      debit_kobo = raw.debit_kobo.to_i
      credit_kobo = raw.credit_kobo.to_i
      unless debit_kobo.positive? ^ credit_kobo.positive?
        raise ArgumentError, "must have either a debit or a credit, not both or neither"
      end

      {
        account: raw.account,
        side: debit_kobo.positive? ? :debit : :credit,
        amount_kobo: debit_kobo.positive? ? debit_kobo : credit_kobo
      }
    end

    def structural_errors(lines)
      errors = []
      errors << "An entry requires at least two lines" if lines.size < 2

      debits, credits = totals(lines)
      unless debits == credits
        errors << "Total debits (#{format_kobo(debits)}) must equal total credits (#{format_kobo(credits)})"
      end

      accounts_on_both_sides = lines.group_by(&:account_id)
        .select { |_account_id, account_lines| account_lines.map(&:side).uniq.size > 1 }
        .keys
      unless accounts_on_both_sides.empty?
        errors << "Account(s) used on both sides: #{accounts_on_both_sides.join(', ')}"
      end

      signatures = lines.map { |line| [ line.account_id, line.side, line.amount_kobo ] }
      errors << "duplicate journal lines are not allowed" if signatures.uniq.size < signatures.size

      errors
    end

    def check_relationships(lines)
      relationships = []
      errors = []
      debits = lines.select { |line| line.side == :debit }
      credits = lines.select { |line| line.side == :credit }

      debits.product(credits).each do |debit, credit|
        law = rules.relationship_for(debit: debit, credit: credit)
        if law
          relationships << RelationshipProof.new(debit.account_id, credit.account_id, law)
        else
          errors << "#{debit.account_name} cannot be debited against #{credit.account_name}"
        end
      end

      [ relationships, errors ]
    end

    def totals(lines)
      [
        lines.select { |line| line.side == :debit }.sum(&:amount_kobo),
        lines.select { |line| line.side == :credit }.sum(&:amount_kobo)
      ]
    end

    def build_proof(lines, relationships)
      debits, credits = totals(lines)
      Proof.new(lines, relationships.freeze, debits, credits)
    end

    def format_kobo(amount_kobo)
      format("%d.%02d", amount_kobo / 100, amount_kobo % 100)
    end
  end
end
