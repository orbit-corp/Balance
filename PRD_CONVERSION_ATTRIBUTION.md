# Stubby — Conversion Attribution & Reconciliation PRD

**Scope:** The conversion-tracking slice of Phase 3 (`PRD.md` §3.1, §12) — closing the loop from "which link got clicked" to "which link/person made the sale," for a market where sales close in WhatsApp DMs and are paid by direct bank transfer. Does not cover affiliate/partner programs, payouts, or fraud (`PRD.md` §3.2–3.4), which build on top of this once it exists.
**Depends on:** Phase 1 shipped — specifically link variants (`PRD_V1.md` §5) and WhatsApp-native links with per-variant ref tags (`PRD_V1.md` §6). This document assumes the ref-tag carrier already exists; it's the mechanism that makes the "which link" question answerable at all.
**Target user:** Same as Phase 1 — the WhatsApp seller / creator-affiliate persona (`PRD.md` §3) — now at the point where they want to know which link actually produced revenue, not just clicks.
**Positioning:** "Prove which link made the sale — even when the deal closed in a DM and the buyer paid by bank transfer."
**Riskiest assumption this tests:** *a seller will forward payment proof to a Stubby WhatsApp bot, and will trust Stubby enough to link a real bank account for confirmation.* Both halves are unvalidated (see §7, and `PRD.md` §10/§11).
**Status:** Speculative Phase 3 design, not approved for implementation. Per project rule, each mechanism below needs its own brainstorm-and-agree pass before build, especially the bank-linking piece.

---

## 1. Problem

`PRD.md` §12 already establishes why click counts alone don't serve the wedge: clicks are gameable, and revenue attribution needs to survive three structural facts about this market —

- **WhatsApp/SMS strip referrers.** The only reliable attribution signal is a ref tag decided at link-creation time (Phase 1's variants), not anything read off the request.
- **Most sales close in a DM, not a checkout.** `stub_id` query params only work if a checkout page catches them — rare when the buyer's next step is "send money to this account number."
- **Most buyers pay by direct bank transfer**, not a payment link, not a card, often not even Paystack/Flutterwave. Any conversion-tracking design anchored on a payment gateway misses the majority case.

Two mechanisms were evaluated and rejected in `PRD.md` §12 before this doc: cookie/JS (dies at the WhatsApp jump) and payment-link-in-path (dies on buyer behavior). Paystack dedicated virtual accounts were also rejected (1,000-account cap, KYC lead time, complexity). This document is the replacement design.

A fourth option — build a Meta-API omnichannel inbox (WhatsApp + Instagram + Messenger) and read conversations directly — was considered and rejected. Reasons, for the record: the WhatsApp Business *app* (used by ~90% of the target persona) has no API at all, so this would require sellers to migrate their number to the Cloud API, a real behavior change, not a checkbox. Instagram/Messenger message access requires Meta App Review and Business Verification — a slow, rejectable dependency for a solo builder. And reading a *third party's* (the buyer's) private conversation content is a much heavier data-protection lift than the click/analytics data already scoped in `PRD.md` §6. Bumpa has built this (IG/FB DMs, WhatsApp added later, in a staged rollout, backed by $4M in funding) — it validates the category but not the sequencing or resourcing fit for this stage of Stubby.

---

## 2. Mechanism: reconciliation, not surveillance

The chosen design borrows the pattern bookkeeping software already uses to close the books — reconcile a self-reported item against a bank feed — and applies it to attribution instead of accounting.

### 2.1 Capture: Stubby-operated WhatsApp bot
- A WhatsApp Business Platform number **operated by Stubby**, not the seller's own number — sellers opt in and message it. This is a standard chatbot integration, not a request for access to anyone's existing business inbox, so it doesn't touch the Meta App Review / WhatsApp-app-migration problems in §1.
- Seller forwards a payment-proof screenshot (the artifact that already exists organically in their sales conversations) and indicates which link/variant it belongs to.
- OCR extracts amount and approximate timestamp from the screenshot as a **match candidate** — not as a verified fact. This is the key design correction from an earlier version of this idea: OCR's job is to produce a search key, not to adjudicate truth. A bad OCR read just fails to find a match; it never falsely vouches for a fake screenshot.
- Seller can also report a sale with no screenshot at all ("I don't know which link" / "cash sale, no proof") — see §4.

### 2.2 Confirmation: open-banking account linking
- Merchant links their bank account via an open-banking/account-aggregation API (Mono, Okra, or equivalent — see §7 for regulatory caveat).
- The OCR match candidate is checked against the real transaction feed: fuzzy match on amount + a date/time window.
- **Matched → confirmed.** **Unmatched → self-reported**, still recorded, never discarded or force-matched.
- **Near-ties** (two similarly-sized sales landing close in time) go to an exceptions queue for the seller to resolve manually — never an automatic guess.
- Paystack/Flutterwave webhook matching (`charge.success` → click ID) remains a secondary, simpler confirmation source for the minority of sellers who do use checkout links.

### 2.3 What this deliberately does not do
- Does not read the seller's WhatsApp/Instagram/Messenger inbox.
- Does not treat OCR output as ground truth.
- Does not require every sale to be forced onto a link (see §4).
- Does not require bank-linking to use the product — self-report without confirmation is always a complete, valid path.

---

## 3. Reconciliation engine (design notes)

- Each submitted payment-proof record: `{seller_id, link_id/variant_id (nullable), ocr_amount, ocr_timestamp, screenshot_ref, status}`.
- `status` ∈ `{self_reported, confirmed, exception, unattributed}`.
- Matching job runs against the linked bank feed on a schedule (or on-demand at submission time if the feed is fresh enough); matches within a configurable amount/time tolerance are auto-confirmed; ambiguous matches (multiple candidates within tolerance) become exceptions.
- Bank feed data is sensitive financial data — store minimally (transaction amount, timestamp, counterparty reference if present), not full statement history, and only what's needed to resolve a match.
- Customer/conversion records tie into the same `Customer` model referenced in `PRD.md` §3.1 (clicks → leads → repeat sales), simplified for v1 of this feature.

---

## 4. Attribution & confirmation honesty (extends `PRD.md` §12)

Two independent honesty axes, both first-class, neither collapsible into the other:

1. **Attribution status** — did the seller know which link produced the sale? (`attributed` / `unattributed`). Decided at the point the seller reports the sale; a high unattributed share tells the seller to put ref-tagged links on more surfaces, and tells Stubby how much selling happens outside the strong (WhatsApp ref-tag) path.
2. **Confirmation status** — was the self-reported amount verified against a real bank transaction? (`confirmed` / `self_reported`). A high self-reported share (relative to confirmed) is a diagnostic of trust/coverage, not a defect — sellers who haven't linked a bank account, or whose bank isn't yet supported, will legitimately live entirely in `self_reported`.

Every dashboard surfacing conversion revenue must show both axes, not just a single blended number. Forcing either axis to resolve (guessing a link, or discarding unconfirmed revenue) rots the data the same way raw click counts did.

---

## 5. Non-Goals (this document)

- Full omnichannel inbox / Meta DM aggregation (see §1 — rejected, not deferred; revisit only as a distinct, later, resourced bet, not as part of this mechanism).
- OCR as a standalone trust signal without bank-feed confirmation.
- Automated matching without a human exceptions path for ambiguous cases.
- Affiliate/partner programs, payouts, fraud tooling (`PRD.md` §3.2–3.4) — this document only produces the conversion record those phases consume.
- Full statement/transaction history retention — only what's needed to resolve a match.

---

## 6. Success Criteria

- % of self-reported conversions that reach `confirmed` status (adoption/trust signal for bank-linking).
- % of conversions with `attributed` status (validates the ref-tag/variant mechanism from Phase 1).
- Median time from sale close to seller reporting it via the bot (activation of the reporting habit itself).
- Exception-queue resolution rate and median time (is the ambiguity manageable, or does it create a chore sellers abandon).
- Opt-in rate for bank-account linking among active sellers (directly tests the riskiest assumption in this document's header).

---

## 7. Risks & Open Questions (see also `PRD.md` §10, §11)

| Risk/Question | Notes |
|---|---|
| Sellers won't link real bank accounts | Heaviest trust ask in the Stubby product to date; market is primed to distrust apps requesting account access (fake loan/investment-app scams). Self-report must remain a complete, non-degraded path regardless of adoption. |
| Open-banking regulatory maturity | Nigeria's CBN open-banking framework isn't fully live yet (phased rollout expected from early 2026); Mono/Okra currently operate proprietary "open finance" connections, not the finished regulated registry model. Build against current APIs; re-evaluate when/if the CBN registry activates. |
| Match ambiguity | Similar-amount sales close in time will collide; exceptions queue is required from day one, not a v2 add-on. |
| WhatsApp Business Platform constraints on the bot itself | Any Stubby-initiated message (reminders, match confirmations) is subject to the 24-hour session window / template-message approval rules — plan the bot's conversational flow around this, not around unrestricted messaging. |
| Screenshot fraud | Because OCR is a candidate, not a verifier, a fake screenshot simply fails to confirm — but confirm the UX doesn't imply "we verified this" before a match actually lands. |

---

## 8. Suggested Build Order

1. Payment-proof submission via the WhatsApp bot, status = `self_reported`/`attributed`-or-not, no bank linking yet (ships value immediately: structured, timestamped conversion records replace nothing-at-all, even pre-confirmation).
2. Open-banking account linking (single provider first, e.g. Mono) behind a feature flag with a small pilot group — validate willingness before broad rollout.
3. OCR extraction + matching engine, confirmed/self-reported split surfaced in the dashboard.
4. Exceptions queue UI for ambiguous matches.
5. Paystack/Flutterwave webhook as secondary confirmation source.
