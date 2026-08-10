# Hardening the accounting harness

An assessment of the LLM-to-ledger path (`LedgerAgent` → `ProposeEntry` →
`Llm::JournalEntryProposal` → `Proposal` → `JournalEntry`) against what production
accounting software needs, ordered by what will hurt first.

Written 2026-08-10, against the state of the code on `ledger-double-entry`.

---

## 1. Money is a float in the tool schema

`ProposeEntry` declares `number :amount_naira`. That arrives as a Float, and
`Float#to_d` is lossy.

Change the tool to take **integer kobo** (`integer :amount_kobo`) or a **string**
parsed with `BigDecimal(value)`. Never let a float touch a ledger amount.

Related, already fixed: `Llm::JournalEntryProposal.from_form` stored `account_id` as a
String while `from_tool` stored an Integer, so after any "Save edits" no `<option>`
matched, the select fell back to the first account alphabetically, and Confirm would
have posted against the wrong account. Both paths now coerce with `.to_i`. The lesson
generalises — **every value crossing the model/form boundary needs an explicit type**,
because `data` is untyped JSONB.

## 2. Confirm is racy and not idempotent

`Llm::ProposalsController#confirm` checks `pending?`, then builds the entry inside a
transaction. Two tabs, or one double-click, can both pass the check and post twice.

Fix with all three:

- `@proposal.with_lock { return unless @proposal.pending?; … }`
- A unique index on `proposals.journal_entry_id`
- A guarded state transition as the gate:
  `Proposal.where(id:, status: "proposed").update_all(status: "confirming") == 1`

## 3. No database-level ledger invariants

Balance and the two-line minimum live only in `JournalEntry` validations, so any
`update_column`, raw SQL, or future CSV import bypasses them.

Add:

- A CHECK constraint that each line has exactly one of `debit_kobo` / `credit_kobo`
  positive and the other zero
- A CHECK that both are `>= 0`
- A deferred constraint or trigger asserting per-entry balance
- A nightly job asserting `SUM(debit_kobo) = SUM(credit_kobo)` per workspace, alerting
  on drift

## 4. Entries are mutable in principle

Routes are `index/new/create` only, which is right, but nothing enforces it.

Make it structural: no `update` / `destroy` on `JournalEntry`, ever. Add **reversing
entries** as the correction mechanism (`reverses_journal_entry_id`). Then port Parka's
`PeriodLock` — once a month is closed, reject any entry dated inside it at the model
level.

## 5. No audit trail

For accounting software this is not optional.

Record, append-only: who confirmed, when, from which IP/session, the exact model and
model version, the proposal JSON as generated, and the proposal JSON as edited by the
human. Proposals are already versioned — extend that into a `ledger_events` table that
is never updated or deleted.

## 6. The agent loop is unbounded

`Llm::ChatTurn` has no iteration cap, no timeout, and no token budget. A local model
that keeps calling `list_accounts` will hang the job and the UI indefinitely.

Add a max tool-call count per turn (5 is plenty), a wall-clock timeout, a token
ceiling, and a user-visible message when any of them trips.

## 7. Tool arguments are not semantically validated

`Llm::JournalEntryProposal` checks presence, sides, positivity, workspace ownership,
and balance. It does not check:

- The same account on both the debit and credit side of one entry
- Duplicate identical lines
- Amounts wildly out of range (a ₦4,000 lunch entered as ₦400,000,000)
- An entry dated in the future, or years in the past

Each should either block or set `needs_attention`, which the proposal card already
renders.

## 8. Unknown accounts should route to Suspense, never be guessed

There is a `Suspense` account. Make the instructions explicit: if the model cannot
identify an account with confidence it must use Suspense and say so — not pick the
closest-sounding name. Then add a "Suspense items" report so nothing quietly rots
there.

The `Other Expense` fallbacks in the current dev data are exactly the failure this
prevents.

## 9. The harness has no tests

The proposal path — tool call → validation → confirm → posted entry — is the highest
risk code in the app and is untested.

Record real model responses to fixtures and test the harness against them with no
model in the loop. Cover at minimum:

- Unbalanced proposal rejected
- Missing account rejected
- Cross-workspace account rejected
- Double-confirm posts exactly once
- Edited-then-confirmed uses the edited values (this would have caught the
  `account_id` type bug)

## 10. No per-turn observability

`ChatUsage` surfaces cost in the UI, but nothing is persisted per turn.

Store tokens, cost, latency, tool-call count, and outcome (proposed / confirmed /
dismissed / failed) per turn. Without it you cannot tell whether a prompt or model
change made the harness better or worse.

## 11. Failures are invisible to the user

`Llm::ChatTurn` rescues nothing; a provider error clears the pending bubble and leaves
silence.

There is an `_error` partial — persist a failed turn and render it, with
retry-with-backoff on the job and distinct messages for "model unreachable" versus
"model produced something invalid".

## 12. Currency is implicit

Everything is kobo and `₦` is hardcoded in the `naira` helper. Fine today.

If multi-currency is ever plausible, add `currency` and `fx_rate` to lines now.
Retrofitting currency into a populated ledger is the most painful migration in
accounting software.
