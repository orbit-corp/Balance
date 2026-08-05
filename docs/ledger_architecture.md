# Ledger Architecture — QuickBooks three-tier taxonomy

Supersedes the current two-tier `account_type`/`account_subtype` shape.

## 1. What changes

Accounts get a **three-tier** classification, matching QuickBooks:

| Tier | Column | Example | Who sets it |
|---|---|---|---|
| Base type | `base_type` | `asset` | system, closed set of 5 |
| Account type | `account_type` | `bank` | user picks, closed set per base type |
| Detail type | `detail_type` | `cash_on_hand` | user picks, closed set per account type |

`base_type` is **stored and authoritative** — never derived by reverse lookup. This is the one place we deliberately
differ from QuickBooks, which infers the group header from the account type. Deriving it is what broke the previous
implementation.

`normal_balance` derives from `base_type` only:
- `asset`, `expense` → debit-normal
- `liability`, `equity`, `income` → credit-normal

## 2. Schema

`20260718000004_create_accounts.rb` is the last migration, and workspaces/users/sessions are created in earlier ones.
So roll back, edit in place, migrate forward — the login and workspace survive:

```bash
bin/rails db:rollback && bin/rails db:migrate
```

No patch migration. No `db:reset` — that would drop the user and workspace too.

```ruby
create_table :accounts do |t|
  t.references :workspace, null: false, foreign_key: true
  t.string :base_type,   null: false
  t.string :account_type, null: false
  t.string :detail_type,  null: false
  t.string :name,         null: false
  t.string :role                      # nil for user-created accounts
  t.text   :description
  t.timestamps
end
add_index :accounts, [:workspace_id, :base_type]
add_index :accounts, [:workspace_id, :account_type]
add_index :accounts, [:workspace_id, :name], unique: true
add_index :accounts, [:workspace_id, :role], unique: true, where: "role IS NOT NULL"
```

Name uniqueness is per workspace, not per type — two accounts called "Bank Charges" under different types would split
the user's own history.

## 3. The taxonomy

One frozen constant is the single source of truth. Both writers and readers go through it.

### The naming rule — read this before touching the taxonomy

`detail_type` is a **closed system taxonomy** whose only job is to drive report sections. It is generic and stays
generic. Business-, region- or user-specific meaning lives in the account **`name`**, which is free-form and renameable.

So there is no `family_support` detail type. There is an account *named* "Family Support" whose detail type is
`other_miscellaneous_expense`. Likewise "Opay Wallet" is `cash_on_hand`, "Ajo Contributions" is `loans_to_others`,
"Generator Fuel" is `auto`, "WHT Receivable" is `prepaid_expense`.

Do not add Nigerian or personal-finance detail types. If a real account has nowhere to sit, use the generic
`other_*` detail type for that account type — those exist precisely as the escape hatch.

```ruby
TAXONOMY = {
  "asset" => {
    "bank"                    => %w[checking savings cash_on_hand money_market],
    "accounts_receivable"     => %w[accounts_receivable],
    "other_current_asset"     => %w[inventory prepaid_expense undeposited_funds
                                    employee_cash_advances loans_to_others other_current_asset],
    "fixed_asset"             => %w[machinery_equipment vehicles furniture_fixtures buildings land
                                    leasehold_improvements accumulated_depreciation],
    "other_asset"             => %w[security_deposits goodwill licenses other_asset],
  },
  "liability" => {
    "credit_card"             => %w[credit_card],
    "accounts_payable"        => %w[accounts_payable],
    "other_current_liability" => %w[sales_tax_payable payroll_liabilities income_tax_payable
                                    deferred_revenue loan_payable line_of_credit
                                    other_current_liability],
    "long_term_liability"     => %w[notes_payable shareholder_notes_payable other_long_term_liability],
  },
  "equity" => {
    "equity"                  => %w[owner_capital owner_draw opening_balance],
  },
  "income" => {
    "income"                  => %w[sales_of_product_income service_fee_income
                                    discounts_refunds_given other_primary_income],
    "other_income"            => %w[interest_earned exchange_gain gain_on_disposal other_income],
  },
  "expense" => {
    "cost_of_goods_sold"      => %w[supplies_materials_cogs cost_of_labour_cogs
                                    shipping_freight_cogs other_costs_of_sales],
    "expense"                 => %w[advertising_promotional auto bad_debts bank_charges
                                    charitable_contributions dues_subscriptions insurance
                                    legal_professional_fees office_general_administrative
                                    payroll_expenses rent_or_lease_of_buildings repair_maintenance
                                    shipping_delivery supplies taxes_paid travel utilities
                                    depreciation other_miscellaneous_expense uncategorised_expense],
    "other_expense"           => %w[exchange_gain_or_loss amortization interest_paid
                                    penalties_settlements loss_on_disposal other_expense],
  },
}.freeze
```

Worked mappings for the accounts in `journal_entry_examples.md`, so the intent is unambiguous:

| Account name | base_type | account_type | detail_type |
|---|---|---|---|
| Family Support, Personal Upkeep, Gifts | expense | `expense` | `other_miscellaneous_expense` |
| Generator Fuel, Transport | expense | `expense` | `auto` |
| Rent Expense | expense | `expense` | `rent_or_lease_of_buildings` |
| Ajo Contributions | asset | `other_current_asset` | `loans_to_others` |
| Ajo Contributions Payable | liability | `other_current_liability` | `other_current_liability` |
| Opay Wallet, Agent Float | asset | `bank` | `cash_on_hand` |
| WHT Receivable, VAT Input Recoverable | asset | `other_current_asset` | `prepaid_expense` |
| Staff Advance | asset | `other_current_asset` | `employee_cash_advances` |
| Landlord Deposit | asset | `other_asset` | `security_deposits` |
| Loan from Owner | liability | `long_term_liability` | `shareholder_notes_payable` |
| VAT Payable | liability | `other_current_liability` | `sales_tax_payable` |
| PAYE / Pension Payable | liability | `other_current_liability` | `payroll_liabilities` |
| Customer Deposits | liability | `other_current_liability` | `deferred_revenue` |
| Phone (Asset) | asset | `fixed_asset` | `machinery_equipment` |
| Salary Income | income | `income` | `other_primary_income` |
| FX Loss | expense | `other_expense` | `exchange_gain_or_loss` |

Validations: `base_type` in `TAXONOMY.keys`; `account_type` in `TAXONOMY[base_type].keys`;
`detail_type` in `TAXONOMY[base_type][account_type]`.

### Contra accounts

`accumulated_depreciation` sits under `fixed_asset` and `discounts_refunds_given` under `income` — both carry a balance
contrary to their base type's normal side. This is QuickBooks' own answer, and adopting it means **signed balances are
allowed**. Every balance, report and health check must tolerate an account running contrary to `normal_balance`. Do not
add a contra flag.

## 4. Core accounts

A code registry owns the list; DB rows are materialized from it. Resolution is by `role`, never by name.

```ruby
CORE = {
  cash:              { name: "Cash",                   base: "asset",     type: "bank",                    detail: "cash_on_hand" },
  receivable:        { name: "Accounts Receivable",    base: "asset",     type: "accounts_receivable",     detail: "accounts_receivable" },
  payable:           { name: "Accounts Payable",       base: "liability", type: "accounts_payable",        detail: "accounts_payable" },
  suspense:          { name: "Suspense",               base: "liability", type: "other_current_liability", detail: "other_current_liability" },
  owner_capital:     { name: "Owner's Equity",         base: "equity",    type: "equity",                  detail: "owner_capital" },
  owner_draw:        { name: "Owner's Drawings",       base: "equity",    type: "equity",                  detail: "owner_draw" },
  opening_balance:   { name: "Opening Balance Equity", base: "equity",    type: "equity",                  detail: "opening_balance" },
  sales:             { name: "Sales",                  base: "income",    type: "income",                  detail: "sales_of_product_income" },
  cogs:              { name: "Cost of Goods Sold",     base: "expense",   type: "cost_of_goods_sold",      detail: "other_costs_of_sales" },
  bank_charges:      { name: "Bank Charges",           base: "expense",   type: "expense",                 detail: "bank_charges" },
  uncategorised_exp: { name: "Uncategorised Expense",  base: "expense",   type: "expense",                 detail: "uncategorised_expense" },
}.freeze

SEED_ON_CREATE = %i[cash sales uncategorised_exp owner_capital].freeze
```

```ruby
def self.for_role!(workspace, role)
  spec = CORE.fetch(role)
  workspace.accounts.find_or_create_by!(role: role) do |a|
    a.name        = spec[:name]
    a.base_type   = spec[:base]
    a.account_type = spec[:type]
    a.detail_type = spec[:detail]
  end
end
```

`SEED_ON_CREATE` runs in `RegistrationsController#create` so a new workspace's account dropdown is not empty. The rest
materialize on first `for_role!`. This means adding a core account later is a one-line registry change — **no
migration, no backfill.**

### Guards

```ruby
before_destroy { throw(:abort) if role.present? }
before_update  { throw(:abort) if role.present? && (base_type_changed? || account_type_changed?) }
```

Renaming a core account stays allowed — "Ajo" vs "Esusu" vs "Adashe" is regional.

## 5. Journal entries

- `JournalEntry`: N lines where N >= 2; `sum(debit_kobo) == sum(credit_kobo)` using `to_i` so a nil amount is invalid
  rather than raising `TypeError`. Delete the exactly-two-lines validation. Add `reject_if: :all_blank` to the nested
  attributes.
- `JournalEntryLine`: single-sided (`debit_kobo` XOR `credit_kobo` positive). Validate the account belongs to the same
  workspace as the entry.
- Add `counterparty_type`/`counterparty_id` (polymorphic, nullable) to `journal_entry_lines` — AR/AP are single accounts,
  so who owes what lives on the line.
- Form: Stimulus add/remove line rows, two by default.

## 6. Reports

Replace `app/queries/ledger_summary.rb`, which still references the deleted `Posting` and `Transaction` and currently
makes `GET /` raise.

- Account balance = `sum(debit) - sum(credit)`, then negate for credit-normal base types on display.
- **Income must be `Σcredit - Σdebit`, expense `Σdebit - Σcredit`.** Summing one column only is wrong — a
  reclassification between two income accounts would inflate revenue.
- `trial_balance`, `balance_sheet(as_of:)`, `profit_and_loss(date_range)`.
- Equity on the balance sheet = equity account balances + (lifetime income − lifetime expense). No closing entries.

## 7. Locked decisions

- Naira only. FX differences post to `fx_loss`/`fx_gain` as ordinary accounts; no revaluation machinery.
- No closing entries, no Retained Earnings account.
- Entries are append-only via routes (index/new/create). No reversal entries yet.
- Keep separate `debit_kobo`/`credit_kobo` columns.
- Signed balances permitted (see Contra accounts).

## 8. Out of scope

Account numbers/codes, `parent_id` sub-account trees, multi-currency revaluation, inventory cost layers (FIFO/average),
depreciation schedules, the posting-template engine, bank reconciliation, items/products.

## 9. One open decision

`owner_draw` (equity) and `personal_upkeep`/`family_support`/`gifts` (expense) both exist in the taxonomy above, and
they model the same money leaving for personal use at two different base types. Example 7 in
`journal_entry_examples.md` books owner money *in* as equity; Example 16 books it *out* as expense.

Recommendation: keep both. A genuine capital withdrawal uses `owner_draw`; day-to-day personal consumption uses the
expense accounts, which keeps the P&L answering "did I make money after everything." The capture UI asks which — the
same disambiguation the gift-vs-loan case needs (Examples 8 and 9).

Nothing in this document depends on resolving it; the engine does.
