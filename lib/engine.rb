# frozen_string_literal: true;

# Double-Entry Bookkeeping Engine (Ruby) — v2
# ===========================================
# Mathematical foundation + account-behaviour model.
#
# Core guarantees:
#   1. Debits == Credits on every entry
#   2. Account-behaviour compatibility (not a brittle matrix)
#   3. Atomic post: balances are only mutated after all checks pass
#   4. Accounting equation holds after every successful post:
#        Assets + Expenses = Liabilities + Equity + Revenue
#
# Design notes (honest):
#   - The behaviour model is better than the previous hard matrices.
#   - It still does not provide semantic correctness (a valid pair can
#     still represent the wrong economic event).
#   - Multi-line validation remains pairwise; true semantic validation
#     requires higher-level transaction types or value-flow analysis.
#   - This is a strong, correct prototype, not a finished production engine.

require "bigdecimal"
require "bigdecimal/util"
require "date"
require "securerandom"

# ---------------------------------------------------------------------------
# Account Types
# ---------------------------------------------------------------------------
module AccountType
  ASSET     = :asset
  LIABILITY = :liability
  EQUITY    = :equity
  REVENUE   = :revenue
  EXPENSE   = :expense

  ALL = [ ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE ].freeze
  DEBIT_NORMAL = [ ASSET, EXPENSE ].freeze
end

# ---------------------------------------------------------------------------
# Account Behaviour Model
# ---------------------------------------------------------------------------
# Describes what each account type *does*.
# Revenue and Expense are reversible (refunds, credit notes, adjustments).
ACCOUNT_BEHAVIOURS = {
  asset: {
    normal_balance: :debit,
    increases_with: :debit,
    decreases_with: :credit,
    # Includes revenue so refunds (Dr Revenue / Cr Asset) are legal
    can_be_debited_against:  %i[asset liability equity revenue],
    can_be_credited_against: %i[asset expense liability equity revenue]
  },

  liability: {
    normal_balance: :credit,
    increases_with: :credit,
    decreases_with: :debit,
    can_be_debited_against:  %i[asset liability equity expense],
    can_be_credited_against: %i[asset liability expense]
  },

  equity: {
    normal_balance: :credit,
    increases_with: :credit,
    decreases_with: :debit,
    can_be_debited_against:  %i[asset equity],
    can_be_credited_against: %i[asset equity revenue]
  },

  revenue: {
    normal_balance: :credit,
    increases_with: :credit,
    decreases_with: :debit,
    # Reversible: refunds, credit notes, adjustments
    can_be_debited_against:  %i[asset revenue expense],
    can_be_credited_against: %i[asset equity]
  },

  expense: {
    normal_balance: :debit,
    increases_with: :debit,
    decreases_with: :credit,
    # Reversible: expense reversals, adjustments, refunds
    can_be_debited_against:  %i[asset liability],
    can_be_credited_against: %i[asset expense liability]
  }
}.freeze

# ---------------------------------------------------------------------------
# Account
# ---------------------------------------------------------------------------
class Account
  attr_reader :code, :name, :account_type
  attr_accessor :debit_total, :credit_total

  def initialize(code, name, account_type)
    raise ArgumentError, "Invalid account type: #{account_type}" unless AccountType::ALL.include?(account_type)

    @code         = code.to_s
    @name         = name.to_s
    @account_type = account_type
    @debit_total  = BigDecimal("0")
    @credit_total = BigDecimal("0")
  end

  def balance
    if AccountType::DEBIT_NORMAL.include?(@account_type)
      @debit_total - @credit_total
    else
      @credit_total - @debit_total
    end
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

  def to_s
    "<Account #{@code} #{@name} (#{@account_type}) bal=#{balance.to_s('F')}>"
  end
end

# ---------------------------------------------------------------------------
# Entry Line
# ---------------------------------------------------------------------------
class EntryLine
  attr_reader :account_code, :debit, :credit, :memo

  def initialize(account_code:, debit: 0, credit: 0, memo: "")
    @account_code = account_code.to_s
    @debit  = debit.to_d.round(2)
    @credit = credit.to_d.round(2)
    @memo   = memo.to_s

    raise ArgumentError, "Amounts must be non-negative" if @debit.negative? || @credit.negative?
    raise ArgumentError, "A line cannot have both debit and credit" if @debit.positive? && @credit.positive?
    raise ArgumentError, "A line must have either a debit or a credit" if @debit.zero? && @credit.zero?
  end

  def debit?
    @debit.positive?
  end

  def credit?
    @credit.positive?
  end
end

# ---------------------------------------------------------------------------
# Journal Entry
# ---------------------------------------------------------------------------
class JournalEntry
  attr_reader :date, :description, :lines, :entry_id, :created_at
  attr_accessor :posted

  def initialize(date:, description:, lines:)
    @date        = date.is_a?(Date) ? date : Date.parse(date.to_s)
    @description = description.to_s
    @lines       = Array(lines)
    @entry_id    = SecureRandom.hex(4)
    @posted      = false
    @created_at  = Time.now.utc
  end

  def total_debits
    @lines.sum(&:debit)
  end

  def total_credits
    @lines.sum(&:credit)
  end

  def balanced?
    total_debits == total_credits
  end

  def validate!
    raise ArgumentError, "Journal entry must have at least two lines" if @lines.size < 2
    raise ArgumentError, "Entry unbalanced: Debits=#{total_debits.to_s('F')} Credits=#{total_credits.to_s('F')}" unless balanced?
  end
end

# ---------------------------------------------------------------------------
# Bookkeeping Engine
# ---------------------------------------------------------------------------
class BookkeepingEngine
  attr_reader :name, :accounts, :journal

  def initialize(name = "Company")
    @name     = name
    @accounts = {}
    @journal  = []
    @closed   = false
  end

  # ---- Chart of Accounts ---------------------------------------------------

  def add_account(code, name, account_type)
    code = code.to_s
    raise ArgumentError, "Account code '#{code}' already exists" if @accounts.key?(code)

    account = Account.new(code, name, account_type)
    @accounts[code] = account
    account
  end

  def get_account(code)
    @accounts.fetch(code.to_s) { raise KeyError, "Account '#{code}' not found" }
  end

  # ---- Behaviour Compatibility ---------------------------------------------

  def compatible?(debit_type, credit_type)
    debit_rules  = ACCOUNT_BEHAVIOURS.fetch(debit_type)
    credit_rules = ACCOUNT_BEHAVIOURS.fetch(credit_type)

    debit_rules[:can_be_debited_against].include?(credit_type) &&
      credit_rules[:can_be_credited_against].include?(debit_type)
  end

  # Pairwise check. This is still not full semantic validation —
  # it only guarantees that every debit type is compatible with
  # at least one credit type present, and vice versa.
  # True multi-line semantic safety requires higher-level transaction types.
  def validate_relationships!(entry)
    debited  = []
    credited = []

    entry.lines.each do |line|
      account = get_account(line.account_code)
      if line.debit?
        debited << account.account_type
      else
        credited << account.account_type
      end
    end

    debited.each do |dtype|
      unless credited.any? { |ctype| compatible?(dtype, ctype) }
        raise ArgumentError,
              "Invalid relationship: debiting #{dtype} is not compatible with credited types #{credited.uniq}"
      end
    end

    credited.each do |ctype|
      unless debited.any? { |dtype| compatible?(dtype, ctype) }
        raise ArgumentError,
              "Invalid relationship: crediting #{ctype} is not compatible with debited types #{debited.uniq}"
      end
    end
  end

  # ---- Posting (atomic) ----------------------------------------------------

  def post(entry)
    raise RuntimeError, "Books are closed for this period" if @closed

    # 1. Structural validation
    entry.validate!

    # 2. Relationship validation (before any mutation)
    validate_relationships!(entry)

    # 3. Snapshot current balances so we can roll back if equation fails
    snapshot = @accounts.transform_values do |acc|
      { debit: acc.debit_total, credit: acc.credit_total }
    end

    begin
      # 4. Apply the entry
      entry.lines.each do |line|
        account = get_account(line.account_code)
        if line.debit?
          account.debit(line.debit)
        else
          account.credit(line.credit)
        end
      end

      # 5. Equation check
      unless equation_holds?
        raise RuntimeError, "Accounting equation broken after posting"
      end

      # 6. Commit
      entry.posted = true
      @journal << entry
      entry
    rescue StandardError
      # Roll back balances
      snapshot.each do |code, totals|
        acc = @accounts[code]
        acc.debit_total  = totals[:debit]
        acc.credit_total = totals[:credit]
      end
      raise
    end
  end

  def create_and_post(date, description, lines)
    entry_lines = lines.map do |code, debit, credit|
      EntryLine.new(account_code: code, debit: debit, credit: credit)
    end

    entry = JournalEntry.new(date: date, description: description, lines: entry_lines)
    post(entry)
  end

  # ---- Accounting Equation -------------------------------------------------

  def sum_by_type(type)
    @accounts.values
             .select { |a| a.account_type == type }
             .sum(&:balance)
  end

  def equation_holds?(tolerance = BigDecimal("0.01"))
    assets      = sum_by_type(AccountType::ASSET)
    liabilities = sum_by_type(AccountType::LIABILITY)
    equity      = sum_by_type(AccountType::EQUITY)
    revenue     = sum_by_type(AccountType::REVENUE)
    expenses    = sum_by_type(AccountType::EXPENSE)

    left  = assets + expenses
    right = liabilities + equity + revenue
    (left - right).abs <= tolerance
  end

  def equation_status
    assets      = sum_by_type(AccountType::ASSET)
    liabilities = sum_by_type(AccountType::LIABILITY)
    equity      = sum_by_type(AccountType::EQUITY)
    revenue     = sum_by_type(AccountType::REVENUE)
    expenses    = sum_by_type(AccountType::EXPENSE)

    left  = assets + expenses
    right = liabilities + equity + revenue

    {
      assets: assets,
      expenses: expenses,
      left: left,
      liabilities: liabilities,
      equity: equity,
      revenue: revenue,
      right: right,
      difference: left - right,
      holds: (left - right).abs <= BigDecimal("0.01")
    }
  end

  # ---- Reporting -----------------------------------------------------------

  def trial_balance
    rows = []
    total_debit  = BigDecimal("0")
    total_credit = BigDecimal("0")

    @accounts.keys.sort.each do |code|
      acc = @accounts[code]
      debit_bal  = BigDecimal("0")
      credit_bal = BigDecimal("0")

      if AccountType::DEBIT_NORMAL.include?(acc.account_type)
        if acc.balance >= 0
          debit_bal = acc.balance
        else
          credit_bal = acc.balance.abs
        end
      else
        if acc.balance >= 0
          credit_bal = acc.balance
        else
          debit_bal = acc.balance.abs
        end
      end

      total_debit  += debit_bal
      total_credit += credit_bal

      rows << {
        code: code,
        name: acc.name,
        type: acc.account_type,
        debit: debit_bal,
        credit: credit_bal
      }
    end

    {
      rows: rows,
      total_debit: total_debit,
      total_credit: total_credit,
      balanced: total_debit == total_credit
    }
  end

  def income_statement
    revenue  = sum_by_type(AccountType::REVENUE)
    expenses = sum_by_type(AccountType::EXPENSE)
    {
      revenue: revenue,
      expenses: expenses,
      net_income: revenue - expenses
    }
  end

  def balance_sheet_snapshot
    assets      = sum_by_type(AccountType::ASSET)
    liabilities = sum_by_type(AccountType::LIABILITY)
    equity      = sum_by_type(AccountType::EQUITY)
    net_income  = sum_by_type(AccountType::REVENUE) - sum_by_type(AccountType::EXPENSE)
    total_equity = equity + net_income

    {
      assets: assets,
      liabilities: liabilities,
      equity_including_net_income: total_equity,
      liabilities_plus_equity: liabilities + total_equity,
      balanced: assets == liabilities + total_equity
    }
  end

  # ---- Pretty printers -----------------------------------------------------

  def print_trial_balance
    tb = trial_balance
    puts "\n#{'=' * 70}"
    puts "TRIAL BALANCE — #{@name}"
    puts "=" * 70
    printf "%-10s %-30s %12s %12s\n", "Code", "Account", "Debit", "Credit"
    puts "-" * 70

    tb[:rows].each do |row|
      d = row[:debit].zero?  ? "" : format("%.2f", row[:debit])
      c = row[:credit].zero? ? "" : format("%.2f", row[:credit])
      printf "%-10s %-30s %12s %12s\n", row[:code], row[:name], d, c
    end

    puts "-" * 70
    printf "%-41s %12.2f %12.2f\n", "TOTAL", tb[:total_debit], tb[:total_credit]
    puts "Balanced: #{tb[:balanced]}"
    puts
  end

  def print_equation
    s = equation_status
    puts "\n#{'=' * 60}"
    puts "ACCOUNTING EQUATION CHECK"
    puts "=" * 60
    printf "Assets          %15.2f\n", s[:assets]
    printf "+ Expenses      %15.2f\n", s[:expenses]
    printf "= Left side     %15.2f\n", s[:left]
    puts
    printf "Liabilities     %15.2f\n", s[:liabilities]
    printf "+ Equity        %15.2f\n", s[:equity]
    printf "+ Revenue       %15.2f\n", s[:revenue]
    printf "= Right side    %15.2f\n", s[:right]
    puts
    printf "Difference      %15.2f\n", s[:difference]
    puts "Equation holds: #{s[:holds]}"
    puts
  end
end

# ---------------------------------------------------------------------------
# Demo / self-test
# ---------------------------------------------------------------------------
if __FILE__ == $PROGRAM_NAME
  engine = BookkeepingEngine.new("Demo Company Ltd")

  engine.add_account("1000", "Cash",                AccountType::ASSET)
  engine.add_account("1100", "Accounts Receivable", AccountType::ASSET)
  engine.add_account("1500", "Inventory",           AccountType::ASSET)
  engine.add_account("2000", "Accounts Payable",    AccountType::LIABILITY)
  engine.add_account("3000", "Owner's Equity",      AccountType::EQUITY)
  engine.add_account("4000", "Sales Revenue",       AccountType::REVENUE)
  engine.add_account("5000", "Cost of Goods Sold",  AccountType::EXPENSE)
  engine.add_account("5100", "Rent Expense",        AccountType::EXPENSE)

  today = Date.today

  engine.create_and_post(today, "Owner capital contribution", [
    [ "1000", 10_000, 0 ],
    [ "3000", 0, 10_000 ]
  ])

  engine.create_and_post(today, "Purchase inventory on account", [
    [ "1500", 3_000, 0 ],
    [ "2000", 0, 3_000 ]
  ])

  engine.create_and_post(today, "Cash sale", [
    [ "1000", 2_500, 0 ],
    [ "4000", 0, 2_500 ]
  ])

  engine.create_and_post(today, "Record COGS for cash sale", [
    [ "5000", 1_200, 0 ],
    [ "1500", 0, 1_200 ]
  ])

  engine.create_and_post(today, "Credit sale", [
    [ "1100", 1_800, 0 ],
    [ "4000", 0, 1_800 ]
  ])

  engine.create_and_post(today, "Record COGS for credit sale", [
    [ "5000", 900, 0 ],
    [ "1500", 0, 900 ]
  ])

  engine.create_and_post(today, "Pay monthly rent", [
    [ "5100", 800, 0 ],
    [ "1000", 0, 800 ]
  ])

  engine.create_and_post(today, "Customer payment received", [
    [ "1000", 1_000, 0 ],
    [ "1100", 0, 1_000 ]
  ])

  # Demonstrate a revenue reversal (now allowed)
  engine.create_and_post(today, "Sales refund / credit note", [
    [ "4000", 200, 0 ],   # Debit Revenue (reversal)
    [ "1000", 0, 200 ]    # Credit Cash
  ])

  engine.print_trial_balance
  engine.print_equation

  puts "Income Statement:"
  engine.income_statement.each { |k, v| printf "  %-20s %12.2f\n", k, v }

  puts "\nBalance Sheet Snapshot:"
  engine.balance_sheet_snapshot.each { |k, v| puts "  #{k}: #{v}" }
end
