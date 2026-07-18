# Kickoff — Implement Layer 1 (for Sonnet)

## Objective
Implement **all of Layer 1** exactly as specified in `LAYER1_DIRECTION.md`. That file is the single source of truth for scope, schema, decisions, and the acceptance criteria (§11) and out-of-scope list (§12). **Read it in full before writing any code.** If anything there is ambiguous, stop and ask — do not guess or expand scope.

## How to work (token & quality discipline — follow this)
1. **Backend before frontend.** Complete and test all backend work (removal, auth/workspace, models, validations, query object, controllers, routes, tests) before touching design/views beyond the minimum needed to exercise the backend.
2. **One feature per fresh context.** Work each slice below as a standalone unit in its own clean session/context — do not carry the whole project history forward. Read only `LAYER1_DIRECTION.md` plus the specific files that slice touches. This keeps focus high and token spend low.
3. **Checkpoint each slice:** make it pass its tests, run `bin/rubocop` + `bin/brakeman` clean, commit, then start the next slice in a fresh context.
4. **Be economical:** targeted file reads (not whole-tree scans), focused diffs, and short status output. Run only the relevant tests per slice; run the full suite once at the end.

### Suggested slices (each its own context)
**Backend**
- B1. Remove the shortener (per §1) + clean routes. *(Migrations are already cleaned — do not add a drop-migration; your Layer 1 migrations are the first.)*
- B2. Auth + Workspace + Registration (signup creates workspace, seeds categories, logs in) — §3.
- B3. Models + validations + money accessor (Category, Customer, Transaction) — §4–5.
- B4. `LedgerSummary` query object (today/week/month income, expense, profit) — §7.
- B5. Controllers + routes (Dashboards, Transactions, Customers) with minimal views + strong params + workspace scoping — §6–7.
- B6. Tests: model, request/integration (incl. workspace isolation) — §10.

**Frontend** (only after backend is green)
- F1. App layout + sidebar (design direction below).
- F2. Dashboard view: period cards + recent feed + empty state.
- F3. Transaction form: income/expense toggle, Turbo Stream updates, Stimulus category filter.
- F4. Customers views.
- F5. System test (signup → log a sale → see it in feed + Today totals) + visual polish.

## Design direction (frontend slices only)
- **Reference:** open `https://ui.shadcn.com/blocks#dashboard-01` in Chrome and study the **typography, spacing, neutral color palette, sidebar structure, and interaction/behavior.** Match that visual language.
- **Use the attached images** for the sidebar and the overall page scope/feel. **Do NOT copy the reference's main content area** — the dashboard body follows `LAYER1_DIRECTION.md` (period-total cards + recent-entries feed), not shadcn's charts/tables.
- **Build it in plain Tailwind + ERB + Hotwire.** Do **not** install shadcn, React, RubyUI, Phlex, or any UI/component gem — the only permitted new gem is `bcrypt`. You are matching a *look*, not importing a library.
- Mobile-first, server-rendered, <150KB initial load. Large tap targets, single-column on phone, sidebar collapsing appropriately.

## Definition of done
All of `LAYER1_DIRECTION.md` §11 acceptance criteria met, nothing from §12 built, full test suite + rubocop + brakeman green, shortener fully removed. When finished, report: what was built, files added/changed/removed, and the test run output. Keep the summary concise.
