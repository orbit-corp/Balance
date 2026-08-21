# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"
require "date"
require "securerandom"

module AccountType
  ASSET     = :asset
  LIABILITY = :liability
  EQUITY    = :equity
  REVENUE   = :revenue
  EXPENSE   = :expense

  ALL = [ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE].freeze
end

# ============================================================
# 1. ACCOUNT BEHAVIOUR
# ============================================================

ACCOUNT_BEHAVIOURS = {
  asset: {
    normal_balance: :debit,
    debit_effect:   :increase,
    credit_effect:  :decrease
  },

  liability: {
    normal_balance: :credit,
    debit_effect:   :decrease,
    credit_effect:  :increase
  },

  equity: {
    normal_balance: :credit,
    debit_effect:   :decrease,
    credit_effect:  :increase
  },

  revenue: {
    normal_balance: :credit,
    debit_effect:   :decrease,
    credit_effect:  :increase
  },

  expense: {
    normal_balance: :debit,
    debit_effect:   :increase,
    credit_effect:  :decrease
  }
}.freeze

# ============================================================
# 2. RELATIONSHIP RULES
# ============================================================
#
# This layer asks:
# "Given the value effects produced by two account types,
#  is that relationship allowed?"
#
# It does NOT determine what the transaction means.
#
# Semantic classification belongs above this layer.

RELATIONSHIP_RULES = {
  increase: {
    asset:     %i[asset liability equity revenue],
    liability: %i[asset expense],
    equity:    %i[asset revenue],
    revenue:   %i[asset],
    expense:   %i[asset liability]
  },

  decrease: {
    asset:     %i[asset liability equity expense],
    liability: %i[asset liability],
    equity:    %i[asset equity],
    revenue:   %i[asset revenue],
    expense:   %i[asset expense]
  }
}.freeze

# ============================================================
# 3. ACCOUNT
# ============================================================

class Account
  attr_reader :code, :name, :account_type
  attr_accessor :debit_total, :credit_total

  def initialize(code, name, account_type)
    raise ArgumentError, "Invalid account type" unless AccountType::ALL.include?(account_type)

    @code         = code.to_s
    @name         = name.to_s
    @account_type = account_type
    @debit_total  = BigDecimal("0")
    @credit_total = BigDecimal("0")
  end

  def debit(amount)
    amount = amount.to_d
    raise ArgumentError, "Amount must be non-negative" if amount.negative?

    @debit_total += amount
  end

  def credit(amount)
    amount = amount.to_d
    raise ArgumentError, "Amount must be non-negative" if amount.negative?

    @credit_total += amount
  end

  def balance
    behaviour = ACCOUNT_BEHAVIOURS.fetch(@account_type)

    if behaviour[:normal_balance] == :debit
      @debit_total - @credit_total
    else
      @credit_total - @debit_total
    end
  end

  def effect_for(side)
    behaviour = ACCOUNT_BEHAVIOURS.fetch(@account_type)
    behaviour.fetch(:"#{side}_effect")
  end
end

# ============================================================
# 4. ENTRY LINE
# ============================================================

class EntryLine
  attr_reader :account_code, :debit, :credit, :memo

  def initialize(account_code:, debit: 0, credit: 0, memo: "")
    @account_code = account_code.to_s
    @debit        = debit.to_d.round(2)
    @credit       = credit.to_d.round(2)
    @memo         = memo.to_s

    raise ArgumentError, "Amounts must be non-negative" if @debit.negative? || @credit.negative?
    raise ArgumentError, "A line cannot contain both debit and credit" if @debit.positive? && @credit.positive?
    raise ArgumentError, "A line must contain a debit or credit" if @debit.zero? && @credit.zero?
  end

  def side
    debit.positive? ? :debit : :credit
  end

  def amount
    debit.positive? ? debit : credit
  end
end

# ============================================================
# 5. JOURNAL ENTRY
# ============================================================

class JournalEntry
  attr_reader :date, :description, :lines, :entry_id
  attr_accessor :posted

  def initialize(date:, description:, lines:)
    @date        = date.is_a?(Date) ? date : Date.parse(date.to_s)
    @description = description.to_s
    @lines       = Array(lines)
    @entry_id    = SecureRandom.hex(4)
    @posted      = false
  end

  def total_debits
    lines.sum(&:debit)
  end

  def total_credits
    lines.sum(&:credit)
  end

  def balanced?
    total_debits == total_credits
  end

  def validate!
    raise ArgumentError, "Journal entry requires at least two lines" if lines.size < 2
    raise ArgumentError, "Debits must equal credits" unless balanced?
  end
end

# ============================================================
# 6. ENGINE
# ============================================================

class BookkeepingEngine
  attr_reader :accounts, :journal

  def initialize
    @accounts = {}
    @journal  = []
  end

  def add_account(code, name, type)
    raise ArgumentError, "Account already exists" if @accounts.key?(code.to_s)

    account = Account.new(code, name, type)
    @accounts[account.code] = account
    account
  end

  def get_account(code)
    @accounts.fetch(code.to_s)
  end

  # ----------------------------------------------------------
  # VALUE EFFECT
  # ----------------------------------------------------------

  def value_effect(line)
    account = get_account(line.account_code)

    {
      account: account,
      type: account.account_type,
      side: line.side,
      effect: account.effect_for(line.side),
      amount: line.amount
    }
  end

  # ----------------------------------------------------------
  # RELATIONSHIP VALIDATION
  # ----------------------------------------------------------

  def compatible_effect?(source, target)
    RELATIONSHIP_RULES
      .fetch(source[:effect])
      .fetch(source[:type], [])
      .include?(target[:type])
  end

  def validate_relationships!(entry)
    effects = entry.lines.map { |line| value_effect(line) }

    effects.each do |effect|
      opposite_effects = effects.reject { |other| other.equal?(effect) }

      valid = opposite_effects.any? do |other|
        compatible_effect?(effect, other)
      end

      next if valid

      raise ArgumentError,
            "Invalid relationship: #{effect[:type]} #{effect[:effect]} " \
            "has no compatible account effect"
    end
  end

  # ----------------------------------------------------------
  # ACCOUNTING EQUATION
  # ----------------------------------------------------------

  def balance(type)
    @accounts.values
             .select { |account| account.account_type == type }
             .sum(&:balance)
  end

  def equation_holds?
    assets     = balance(:asset)
    liabilities = balance(:liability)
    equity     = balance(:equity)
    revenue    = balance(:revenue)
    expenses   = balance(:expense)

    (assets + expenses) == (liabilities + equity + revenue)
  end

  # ----------------------------------------------------------
  # ATOMIC POST
  # ----------------------------------------------------------

  def post(entry)
    entry.validate!
    validate_relationships!(entry)

    snapshot = @accounts.transform_values do |account|
      {
        debit: account.debit_total,
        credit: account.credit_total
      }
    end

    begin
      entry.lines.each do |line|
        account = get_account(line.account_code)

        if line.debit.positive?
          account.debit(line.debit)
        else
          account.credit(line.credit)
        end
      end

      raise "Accounting equation violated" unless equation_holds?

      entry.posted = true
      @journal << entry

      entry
    rescue
      snapshot.each do |code, totals|
        account = @accounts.fetch(code)
        account.debit_total  = totals[:debit]
        account.credit_total = totals[:credit]
      end

      raise
    end
  end
end