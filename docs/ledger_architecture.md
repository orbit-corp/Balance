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

### Scope — personal accounts only

This is the **personal** account type and nothing else. The taxonomy below carries only the account types and detail
types a personal ledger needs. Business types (inventory, COGS, sales tax, fixed assets, payroll, FX) are deliberately
absent.

Onboarding will later ask what kind of account the user is creating, and the other branches get added then. Do not
pre-add them now.

```ruby
TAXONOMY = {
  "asset" => {
    "bank"                    => %w[checking savings cash_on_hand],
    "accounts_receivable"     => %w[accounts_receivable],
    "other_current_asset"     => %w[prepaid_expense loans_to_others other_current_asset],
  },
  "liability" => {
    "accounts_payable"        => %w[accounts_payable],
    "other_current_liability" => %w[loan_payable other_current_liability],
  },
  "equity" => {
    "equity"                  => %w[opening_balance],
  },
  "income" => {
    "income"                  => %w[other_primary_income],
    "other_income"            => %w[interest_earned other_income],
  },
  "expense" => {
    "expense"                 => %w[auto bank_charges charitable_contributions insurance
                                    rent_or_lease_of_buildings supplies utilities
                                    other_miscellaneous_expense],
  },
}.freeze
```

All five base types stay — they are the accounting identity and none can be dropped. What shrinks is the account types
and detail types beneath them: 9 account types and 20 detail types, down from 15 and 75.

Worked mappings for the categorisation accounts a personal user would create:

| Account name | base_type | account_type | detail_type |
|---|---|---|---|
| Bank Account (GTBank, Opay) | asset | `bank` | `checking` / `cash_on_hand` |
| Savings | asset | `bank` | `savings` |
| Ajo Contributions | asset | `other_current_asset` | `loans_to_others` |
| Rent Paid in Advance | asset | `other_current_asset` | `prepaid_expense` |
| Ajo Contributions Payable | liability | `other_current_liability` | `other_current_liability` |
| Loan from Family | liability | `other_current_liability` | `loan_payable` |
| Salary | income | `income` | `other_primary_income` |
| Interest Earned | income | `other_income` | `interest_earned` |
| Rent | expense | `expense` | `rent_or_lease_of_buildings` |
| Transport, Generator Fuel | expense | `expense` | `auto` |
| Food & Groceries | expense | `expense` | `supplies` |
| Data & Airtime, Electricity | expense | `expense` | `utilities` |
| Gifts & Donations | expense | `expense` | `charitable_contributions` |
| Health | expense | `expense` | `insurance` |
| Family Support, Personal Upkeep | expense | `expense` | `other_miscellaneous_expense` |

Validations: `base_type` in `TAXONOMY.keys`; `account_type` in `TAXONOMY[base_type].keys`;
`detail_type` in `TAXONOMY[base_type][account_type]`.

### Signed balances

No contra account exists in the personal taxonomy — `accumulated_depreciation` and `discounts_refunds_given` came out
with the business branches. The principle still holds and reports must be written for it now, because those accounts
return with the business type: **an account may carry a balance contrary to its base type's normal side, and every
balance, report and health check must tolerate it.** Do not add a contra flag.

## 4. Core accounts

A code registry owns the list; DB rows are materialized from it. Resolution is by `role`, never by name.

```ruby
CORE = {
  cash:            { name: "Cash",                   base: "asset",     type: "bank",                    detail: "cash_on_hand" },
  receivable:      { name: "Accounts Receivable",    base: "asset",     type: "accounts_receivable",     detail: "accounts_receivable" },
  payable:         { name: "Accounts Payable",       base: "liability", type: "accounts_payable",        detail: "accounts_payable" },
  suspense:        { name: "Suspense",               base: "liability", type: "other_current_liability", detail: "other_current_liability" },
  opening_balance: { name: "Opening Balance Equity", base: "equity",    type: "equity",                  detail: "opening_balance" },
  other_income:    { name: "Other Income",           base: "income",    type: "other_income",            detail: "other_income" },
  other_expense:   { name: "Other Expense",          base: "expense",   type: "expense",                 detail: "other_miscellaneous_expense" },
  bank_charges:    { name: "Bank Charges",           base: "expense",   type: "expense",                 detail: "bank_charges" },
}.freeze

# All eight are structural, so all eight are seeded. Nothing is lazily materialized.
SEED_ON_CREATE = CORE.keys.freeze
```

Names are the canonical accounting terms. Friendlier wording ("your debts", "what you're owed") is a **display
concern** — do not rename accounts to achieve it.

Why each one is required:

| Account | Unrecordable without it |
|---|---|
| Cash | the default money account the engine resolves `:money` to |
| Accounts Receivable | lending money out, ajo contributions, anyone owing the user |
| Accounts Payable | buying on installment, informal borrowing |
| Opening Balance Equity | onboarding — there is no other credit side for a starting balance |
| Suspense | money arrived and the source is genuinely unknown; Cash must still be right |
| Other Income | fallback so an unclassifiable receipt never blocks a post |
| Other Expense | fallback so an unclassifiable payment never blocks a post |
| Bank Charges | the fee leg of every transfer and withdrawal template |

**Not in personal, on purpose:** `owner_capital`, `owner_draw`, `sales`, `cogs`. A person does not inject capital into
their own life — money in is income, not capital — so Opening Balance Equity plus retained income minus expense makes
the balance sheet balance without a capital account. Those four are what the business type adds back.

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

## 9. Consequences of the personal-only scope

Cutting the taxonomy resolves the previously open drawings question: `owner_draw` no longer exists, so personal money
going out is always an expense. That is the right answer for a personal ledger, and the P&L reads as "what came in
minus everything that went out." The question returns with the business type, not before.

Four of the seventeen worked examples become unrecordable until the business type lands, all because they need
account types this taxonomy no longer carries:

| Example | Needs | Removed branch |
|---|---|---|
| 4. Purchase on credit | Inventory | `other_current_asset` → `inventory` |
| 11. Salary with pension | Pension (RSA) | payroll detail types |
| 15. Phone on installment | Phone as an asset | `fixed_asset` |
| 17. Import with FX | Inventory, FX Loss | `other_expense` → `exchange_gain_or_loss` |

Examples 15 and 11 are genuinely personal transactions, so they are the ones to watch. A personal user buying a phone
records it as an expense rather than an asset, which most personal-finance tools do anyway — but it is a real
limitation rather than an oversight, and worth confirming before the taxonomy is treated as settled.
