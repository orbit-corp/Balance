# Layer 1 — Implementation Direction (for the implementing model)

**Read this whole document before writing any code.** It is a complete, self-contained specification for **Layer 1** of Stubby's new direction: a cash-basis bookkeeping ledger for small Nigerian businesses. Implement exactly what is specified here. Where something is marked **OUT OF SCOPE**, do not build it, even partially. Where a value is marked *(adjustable)*, use the given default. If you hit a genuine ambiguity not covered here, stop and ask rather than guessing.

Project: `stubby`. Stack already in place: **Rails 8.1.3, Ruby 3.4.8, PostgreSQL, Hotwire (Turbo + Stimulus), Tailwind (tailwindcss-rails), importmap, Propshaft, Solid Queue/Cache/Cable, Puma.** Minitest for tests (Capybara + Selenium available). Do not add gems except `bcrypt` (see Auth).

**Code style — keep comments minimal.** Prefer self-documenting code: explicit, intention-revealing method and variable names that make the behavior obvious without a comment. Do not scatter explanatory comments through the codebase. A comment is only warranted for genuinely non-obvious *why* (a subtle business rule, a workaround, a security-critical constraint) — never to restate *what* the code plainly does. If you feel the urge to write a comment explaining a line, rename the method/variable or extract a well-named method instead.

---

## 0. Context (why this exists)

Stubby is pivoting from a URL shortener to a bookkeeping + reconciliation + link-attribution app for African small businesses that sell over WhatsApp/Instagram/Facebook (design rationale in `PRD_V2_BOOKKEEPING.md`). This task builds **Layer 1 only**: the cash-basis ledger and dashboard, plus the minimal auth/workspace it must hang off. Layers 2–4 (WhatsApp capture, bank reconciliation, link attribution) are **future work — do not build or scaffold them.**

The target user runs a micro-business from a low-end Android phone on 3G. Every screen must be **mobile-first, server-rendered, and lightweight (<150KB initial load).** No SPA, no client-side framework beyond Stimulus.

---

## 1. First task — remove the URL shortener completely

The old product must be fully removed. Delete these files:

- `app/models/short_link.rb`
- `app/controllers/short_links_controller.rb`
- `app/views/short_links/` (entire directory)
- `lib/base62.rb`

Update `config/routes.rb`: remove `root "short_links#new"`, the `post "links"` route, and the greedy `get ":short_code"` catch-all. (New routes in §5.)

**Migrations are already cleaned up** — the `create_short_links` migration has been deleted and `db/schema.rb` reset to an empty baseline (`version: 0`, no tables). Do **not** add a `DropShortLinks` migration; there is nothing to drop. Your Layer 1 migrations (§4) are the first real migrations in this project. After writing them, run `bin/rails db:migrate` so `db/schema.rb` regenerates with only the Layer 1 tables — do not hand-edit `db/schema.rb`.

Update `README.md` to reflect the new direction (one or two lines is enough — a bookkeeping app, not a shortener).

Grep the codebase for `short_link`, `short_code`, `base62`, `shorten` afterward and confirm zero remaining references in `app/`, `lib/`, `config/`, and `test/`.

---

## 2. Locked product decisions (do not deviate)

- **Cash-basis single-entry** ledger. NOT double-entry. No debits/credits, no chart of accounts.
- Scope: **sales (income), expenses, and customers.** Nothing else.
- **Strictly NGN.** Store money as **integer kobo** (₦1 = 100 kobo). No multi-currency, no currency column.
- **Web dashboard only** (no WhatsApp/API entry in this layer).
- A sale's **customer is optional**; an expense has no customer.
- Every transaction **requires a category**, which defaults to "Other" (income defaults to "Sales").
- A recorded sale is **assumed paid** — there is NO paid/unpaid status field. (Receivables are out of scope.)
- Dashboard leads with **period totals + profit** and a recent-entries feed.
- **Plain Tailwind**, hand-built components. Do not add RubyUI/Phlex or any UI gem.
- Timezone: **Africa/Lagos (WAT).** Set `config.time_zone = "Africa/Lagos"`.

---

## 3. Authentication & workspace

Use **Rails 8's built-in authentication generator** (`bin/rails generate authentication`). This produces session-based auth with `has_secure_password`, a `User` and `Session` model, `SessionsController`, `PasswordsController`, a `Current` object, and an `Authentication` concern. **Uncomment `gem "bcrypt"` in the Gemfile** and `bundle install`.

Then add, on top of the generated auth:

- **Registration (signup):** a `RegistrationsController` (`new`, `create`), accessible without authentication (`allow_unauthenticated_access`). Signup form fields: **business name, email, password.** On successful signup, in a single transaction: create the `Workspace` (name = business name), create the `User` (belongs to that workspace), **seed the default categories** for the workspace (§4), start a session, and redirect to the dashboard.
- A single user per workspace in v1. Model the association as `Workspace has_many :users` / `User belongs_to :workspace` anyway (future-proofing), but only ever create one.
- Add a `current_workspace` helper on `ApplicationController` returning `Current.user.workspace`. **Every query for customers, categories, and transactions must be scoped through `current_workspace`** — never a bare `Transaction.all`. This is the multi-tenant boundary and is security-critical.
- Password reset: keep the generator's flow. Email delivery config is out of scope — leave the default (dev delivery/logging). Do not build custom mailers.

---

## 4. Database schema

All tables carry `workspace_id` (FK, indexed, `null: false`) except `users`/`sessions` from the generator. Use `bigint` FKs, `null: false` where stated, timestamps on all.

### workspaces
| column | type | notes |
|---|---|---|
| name | string | null: false |

### users (from generator) — add:
| column | type | notes |
|---|---|---|
| workspace_id | bigint | FK, null: false, indexed |

### categories
| column | type | notes |
|---|---|---|
| workspace_id | bigint | FK, null: false |
| kind | integer | enum {income:0, expense:1}, null: false |
| name | string | null: false |

Index: `[:workspace_id, :kind]`. **Seed defaults per workspace at signup:**
- income *(adjustable)*: **Sales**, **Other**
- expense *(adjustable)*: **Restock**, **Transport**, **Data/Airtime**, **Rent**, **Utilities**, **Fees**, **Other**

### customers
| column | type | notes |
|---|---|---|
| workspace_id | bigint | FK, null: false |
| name | string | null: false |
| phone | string | null: true, indexed (NOT unique in v1) |

### transactions (the ledger spine)
| column | type | notes |
|---|---|---|
| workspace_id | bigint | FK, null: false |
| kind | integer | enum {income:0, expense:1}, null: false |
| amount_kobo | integer | null: false, must be > 0 |
| category_id | bigint | FK, null: false |
| customer_id | bigint | FK, null: true (income only) |
| occurred_on | date | null: false, default = today |
| note | text | null: true |

Indexes: `[:workspace_id, :occurred_on]` (drives dashboard period queries), plus `category_id`, `customer_id`, `[:workspace_id, :kind]`.

Note: use `kind`, **not** `type` (Rails reserves `type` for STI).

---

## 5. Models

- **Workspace** — `has_many :users, :customers, :categories, :transactions, dependent: :destroy`. Validates `name` presence.
- **User** — as generated, plus `belongs_to :workspace`.
- **Category** — `belongs_to :workspace`; `has_many :transactions`; `enum :kind, { income: 0, expense: 1 }`. Validates `name` presence, `kind` presence, and uniqueness of `name` scoped to `[:workspace_id, :kind]`.
- **Customer** — `belongs_to :workspace`; `has_many :transactions`. Validates `name` presence.
- **Transaction** — `belongs_to :workspace`; `belongs_to :category`; `belongs_to :customer, optional: true`; `enum :kind, { income: 0, expense: 1 }`. Validations:
  - `amount_kobo`: presence, integer, greater than 0.
  - `kind`, `occurred_on`: presence.
  - **Category kind must match transaction kind** (an income transaction must use an income category) — custom validation.
  - **Customer, if present, must belong to the same workspace** — custom validation. Same for category.
  - A customer may only be set when `kind == income` (expenses have no customer) — custom validation.
  - **Money accessor:** provide a virtual `amount` accessor for forms. `amount=` parses a naira string/number via `BigDecimal` and stores `(value * 100).round` into `amount_kobo` (never use Float for money). `amount` returns `amount_kobo / 100` as a BigDecimal. Add a helper for display formatting (`₦1,500.00`, thousands-delimited).

---

## 6. Routes

Declare (no catch-all anywhere):

```ruby
resource  :session
resource  :registration, only: [:new, :create]
resources :passwords, param: :token          # from generator
resource  :dashboard,    only: [:show]
resources :transactions
resources :customers
root "dashboards#show"
```

Unauthenticated users hitting an authenticated route are redirected to sign-in by the generated `Authentication` concern. `registrations#new/create` and the session/password routes are the only unauthenticated-accessible ones.

---

## 7. Controllers & UX flows

All controllers require authentication (default) except registration/session/passwords. All data access scoped via `current_workspace`.

### DashboardsController#show (the landing screen)
Computes, via a **`LedgerSummary` query object** (`app/queries/ledger_summary.rb` or a model scope), for the current workspace:
- **Today**, **This week** (Monday start), **This month**: `income_kobo`, `expense_kobo`, `profit_kobo = income − expense`, each a single grouped aggregate query over `transactions.occurred_on`.
- **Recent feed:** the latest ~20 transactions (all kinds), newest first, with kind badge, formatted amount, category name, customer name (if any), and date.

Layout: three compact period cards at top (each showing in / out / profit), a prominent **"Add sale"** and **"Add expense"** action, then the recent feed below. Mobile-first single column.

### TransactionsController (`new`, `create`, `edit`, `update`, `destroy`; `index` optional)
One shared form partial. Fields: **kind** (income/expense — can be preset via `?kind=income` from the dashboard buttons), **amount** (naira input), **category** (select, filtered to the chosen kind, default "Sales" for income / "Other" for expense), **customer** (income only; optional select of existing customers + a way to add a new one — a simple "＋ New customer" that creates one, either inline or via the customers form; keep it simple), **occurred_on** (date, defaults today), **note** (optional).

On `create`/`update` success: respond with **Turbo Stream** that (a) prepends/updates the entry in the recent feed and (b) refreshes the period-total cards — no full page reload. Provide an HTML redirect-to-dashboard fallback for non-Turbo requests. On validation failure, re-render the form with errors (422).

`destroy`: remove the entry and update totals + feed via Turbo Stream.

Strong params: permit only `kind, amount, category_id, customer_id, occurred_on, note`. Assign `workspace` from `current_workspace` server-side — never from params.

### CustomersController (`index`, `new`, `create`, `edit`, `update`, `destroy`)
Basic CRUD scoped to workspace. `index` lists customers with name + phone. Nothing fancy.

### A small Stimulus controller
One controller to **filter the category `<select>` options by the selected kind** on the transaction form (income categories when income is chosen, expense when expense). Keep JS minimal; no other client logic required.

---

## 8. Views & styling

Plain Tailwind, hand-built partials. Mobile-first (single column, large tap targets, sticky primary action). Keep total page weight small. Use `number_to_currency`-style formatting via the money helper with a `₦` unit and no decimals shown when whole *(adjustable — showing `.00` is fine)*. Empty states matter: a fresh workspace with no transactions should show a friendly "Log your first sale" prompt, not a blank screen.

---

## 9. Seeds & config

- `config.time_zone = "Africa/Lagos"` (application config).
- Default categories are seeded **per workspace at signup** (§3/§4), not globally in `db/seeds.rb`. `db/seeds.rb` may optionally create a demo workspace+user for local dev, but that is not required.

---

## 10. Testing (required — implementation is not done without these)

Minitest. Write and make passing:

- **Model tests:** Transaction validations (amount > 0 rejected at 0 and negative; category-kind-must-match-transaction-kind; customer only on income; cross-workspace category/customer rejected). Category name uniqueness per (workspace, kind). Money accessor: `amount = "1500.50"` → `amount_kobo == 150050`.
- **Request/integration tests:** signup creates a workspace + seeds categories + logs in and lands on dashboard; creating an income and an expense changes the dashboard totals correctly; **workspace isolation** — a user cannot read or mutate another workspace's transactions/customers (expect 404/redirect, never another workspace's data).
- **System test (Capybara):** the core flow — sign up → log a sale → see it in the feed and reflected in "Today" totals.

Run `bin/rails test` and `bin/rails test:system` green. Run `bin/rubocop` (rails-omakase) and `bin/brakeman` clean (fix, don't suppress).

---

## 11. Acceptance criteria (definition of done)

1. All shortener code/routes/table removed; grep for `short_link|short_code|base62|shorten` returns nothing in `app/`, `lib/`, `config/`, `test/`.
2. A new user can sign up (business name + email + password), which creates a workspace with the seeded categories and logs them in.
3. Authenticated user lands on a dashboard showing today/week/month income, expense, and profit, plus a recent-entries feed.
4. User can add, edit, and delete income and expense entries; totals and feed update via Turbo Stream without full reload.
5. Sales may attach an optional customer; expenses cannot. Every entry has a category (defaulting correctly).
6. All money is stored and computed in integer kobo; no floating-point money math anywhere.
7. All data is workspace-scoped; cross-workspace access is impossible.
8. Timezone is Africa/Lagos. NGN-only throughout.
9. Full test suite (unit + request + one system test) passes; rubocop + brakeman clean.
10. Mobile-first, server-rendered, no SPA; plain Tailwind only; no new gems except `bcrypt`.

---

## 12. Explicitly OUT OF SCOPE — do NOT build (even partially)

Double-entry / chart of accounts · invoices / receipts · receivables / debt tracking / paid-unpaid status · inventory / products / line-items · multi-currency or any non-NGN handling · WhatsApp/Instagram/Facebook integration or any chatbot (Layer 2) · bank-account linking / open-banking / reconciliation (Layer 3) · link shortening / attribution / click tracking / analytics beyond the ledger totals (Layer 4) · multi-user workspaces / member invites / roles · Google OAuth · public API / webhooks · billing / plans · reports export (CSV/PDF) · charts/graphs (the dashboard is numeric cards + a list; no charting library). If you think one of these is needed, stop and ask.

---

*When done, produce a short summary of what was built, the list of files added/changed/removed, and the test run output. The reviewing model will verify against §11 and §12.*
