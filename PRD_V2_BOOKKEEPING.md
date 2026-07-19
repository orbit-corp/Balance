# Stubby V2 Direction — Bookkeeping + Reconciliation + Link Attribution

**Status:** Proposal / brainstorming input. **Nothing here is approved for implementation.** Per the project working rule, every mechanism below needs its own brainstorm-and-agree pass before any code is written. This document exists to change the *direction* of the product thinking, not to authorize a build.

**Relationship to existing docs:** `PRD_V1.md` (link-shortener MVP) is left intact and remains the reference for the shipped link/redirect/analytics primitives. This document proposes a re-centering: bookkeeping and reconciliation move from a Phase-3 add-on (`PRD.md` #3.1, `PRD_CONVERSION_ATTRIBUTION.md`) to the *core* of what Stubby is. It reuses, rather than discards, the link-attribution machinery already specified.

**Author's framing:** Victor's one-liner — *"QuickBooks + Dub for African small businesses that run on WhatsApp/Instagram/Facebook."* One place to record and reconcile every business transaction (including via WhatsApp), see which shared links actually drive sales, and run the whole workflow from a phone.

---

## 0. How to read this document

Because you asked me to make **no unverified assumptions**, every claim is tagged:

- **[VERIFIED]** — confirmed by this round of research (sources at the end) or already established in the existing PRDs.
- **[UNCERTAIN]** — plausible but not confirmed; do not build load-bearing decisions on it without checking.
- **[NEEDS YOUR CALL]** — a product/strategy decision that is yours, not mine, to make. These are collected in §10.
- **[CONTRADICTS EXISTING PRD]** — new research disagrees with something written in `PRD.md`/`PRD_CONVERSION_ATTRIBUTION.md`; flagged so you can reconcile them.

I have deliberately not resolved the [NEEDS YOUR CALL] items myself.

---

## 1. The reframed problem

Most Nigerian (and broader African) small businesses run sales through social apps — WhatsApp, Instagram, Facebook — and record the business side of those sales in a notebook, a phone note, or nowhere. Money comes in mostly by **direct bank transfer**, not card or checkout. The result is three chronic pains, and today they're solved by three different (or zero) tools:

1. **Record-keeping is manual and lossy.** Sales, expenses, who-owes-what — kept by hand or not at all. [VERIFIED: this is the exact gap Kippa/Bumpa/OZÉ/Sabi built into.]
2. **Reconciliation is guesswork.** A buyer says "I've paid," sends a screenshot; the seller has no fast, trustworthy way to confirm the money actually landed against their real bank feed. Fake-transfer/fake-alert fraud is an active, documented problem. [VERIFIED]
3. **Marketing spend is unmeasured.** A seller shares one business link across WhatsApp status, Instagram bio, Facebook, and paid ads, and cannot tell which placement produced sales. [VERIFIED: "difficulty measuring performance" is the #1 marketing complaint in this segment per existing `PRD.md` #2.]

**The Stubby bet:** these three pains share one spine — a **customer/transaction record that is born at the click and closed at the bank feed.** Whoever owns that spine owns the SME's daily workflow. QuickBooks owns the ledger but not the link or the WhatsApp sale; Dub owns the link but not the ledger or the bank feed. Stubby proposes to own the seam between them, for this specific market. [This is a thesis, not a verified fact — see §10.]

---

## 2. What the market already looks like (so we don't repeat failures)

- **Kippa** — bookkeeping app for merchants, raised ~$11.6M+. Research this round found strong signal that it **shut down / went inaccessible to users from Jan 2024, founders exited by mid-2025**, citing failure to monetize small merchants and intense SME-fintech competition. [UNCERTAIN — two sources point this way, one product page still reads "active"; **verify directly before treating either as fact**, but the monetization-failure lesson is the important takeaway regardless.] **Implication for us:** free bookkeeping for micro-merchants is a known graveyard. Stubby needs a revenue path that isn't "charge broke micro-merchants a subscription for a ledger."
- **Bumpa** — Lagos, ~$4M+ raised; storefront + inventory + bookkeeping + WhatsApp order routing. Active, marketing 2026 tax-compliance features. [VERIFIED] The closest full-stack competitor.
- **Catlog** — WhatsApp-native: shoppable link → order lands as a WhatsApp chat → Paystack for payment. ~₦6,500/mo. [VERIFIED] Validates the WhatsApp-commerce link pattern.
- **Sabi / OZÉ / Prospa / Brass** — various mixes of bookkeeping, receivables, and business banking. [VERIFIED at a high level.]
- **Nobody found** is doing **link-level attribution tied to bank-transfer-reconciled sales** for this segment. [UNCERTAIN — absence of evidence from a shallow search, not proof of a clear market; treat as an assumption to validate, not a moat.]

**Takeaway:** the *bookkeeping* space is crowded and has real corpses; the *attribution-to-reconciled-sale seam* looks open. Our differentiation should lean on the seam, not on out-featuring Bumpa's storefront.

---

## 3. Proposed product shape (my recommendation)

I'd structure Stubby as **four layers over one shared identity model**, built in this order. This is my proposal; the ordering itself is a [NEEDS YOUR CALL] item (§10).

```
        ┌─────────────────────────────────────────────┐
        │  Layer 4: Attribution & marketing analytics   │  ← "which link/ad made the sale"
        ├─────────────────────────────────────────────┤
        │  Layer 3: Reconciliation (bank feed match)    │  ← "was I actually paid"
        ├─────────────────────────────────────────────┤
        │  Layer 2: WhatsApp-native record capture      │  ← "log it where I already work"
        ├─────────────────────────────────────────────┤
        │  Layer 1: Bookkeeping ledger + dashboard      │  ← "one place for my records"
        └─────────────────────────────────────────────┘
                    Shared spine: Customer / Transaction / Link identity
```

### Layer 1 — Bookkeeping ledger (the anchor)

The system of record: sales, expenses, customers, receivables, simple inventory (optional). A web dashboard plus, critically, WhatsApp capture (Layer 2).

- **Data model — cash-basis single-entry, not full double-entry.** [UNCERTAIN but recommended.] Research could not confirm incumbents' exact schemas, but the feature surface (income/expense, invoices, debts) strongly implies simple cash-basis ledgers, which also match how informal-sector sellers actually think. Full QuickBooks-style double-entry is likely over-engineering for the micro-SMB and a UX tax. **[NEEDS YOUR CALL: do we ever want to graduate a growing business to double-entry, or stay resolutely simple? This affects the schema from day one.]**
- Invoicing + receipts sent via WhatsApp/SMS link, paid/unpaid tracking, debt nudges — **table stakes, not differentiation.** [VERIFIED: universal across incumbents.]
- Reuses the existing `workspace_id`-on-everything pattern from `PRD_V1.md` #1.

### Layer 2 — WhatsApp-native record capture (the wedge)

Let the seller log a sale/expense and forward payment proof from inside WhatsApp, because that's where they already are.

- **Architecture-defining constraint [VERIFIED]:** the free WhatsApp Business *App* (what ~most of this persona uses) has **no API** — Stubby *cannot* read the seller's own inbox. The only viable design is a **Stubby-operated WhatsApp bot number** the seller opts into and messages. (This is exactly the mechanism already reasoned out in `PRD_CONVERSION_ATTRIBUTION.md` #2.1 — this research confirms it.)
- Requires Meta Business Verification + WhatsApp Business Platform (Cloud API) onboarding, a dedicated number, and pre-approved templates for any Stubby-initiated message. [VERIFIED]
- **Pricing reality [VERIFIED, and better than the old PRD assumed]:** as of July 1, 2025 Meta bills **per-template-message**, and *service* conversations (the seller replying within 24h) are **free**. Utility templates within the 24h window are free; marketing/auth templates are paid (Nigeria: roughly $0.01–0.06/msg, figures in transition). A BSP adds ~$49–200/mo. So if the flow is "seller messages the bot, bot replies within 24h," the marginal message cost is near zero — cost only appears when *Stubby* initiates (reminders). This meaningfully de-risks the unit economics vs. the old per-conversation model.
- **UX for low-end phones / low literacy [VERIFIED directionally]:** numbered-menu replies ("reply 1 to log a sale"), local-language/code-switching support, resilient to 3G. Proven at scale by other African WhatsApp bots.

### Layer 3 — Reconciliation (the trust engine)

Match a self-reported sale against the seller's real bank transaction feed.

- **Mechanism [VERIFIED best practice]:** fuzzy match on amount (tolerance band) + date/time window (e.g. ±a few days) + optional reference-string similarity. Confidence tiers: high → auto-confirm, medium → spot-check, low/ambiguous → **exceptions queue** for the seller. This is textbook bank-reconciliation logic and fits our case cleanly.
- **Two honesty axes preserved from `PRD_CONVERSION_ATTRIBUTION.md` #4:** *attribution* (which link) and *confirmation* (verified vs. self-reported) stay independent and first-class. Self-report is always a complete path; bank-linking only *grades* it. I strongly endorse keeping this — it's the design's integrity.
- **OCR of payment screenshots:** **I recommend deferring or dropping this for v1.** [UNCERTAIN whether it's worth building at all.] Both the ingestion and attribution research flagged OCR as likely over-engineering: OCR should only ever produce a *match candidate*, never confirm payment (fake screenshots are rampant). If the bank feed is the real confirmation source, OCR mostly saves a few keystrokes. Recommend: let sellers type the amount; add OCR later only if typing proves to be real friction.

### Layer 4 — Attribution & marketing analytics (the differentiator)

Which shared link / ad placement actually produced reconciled sales.

- **Reuse `PRD_V1.md` #5 link variants wholesale.** [VERIFIED as the correct mechanism]: WhatsApp/social apps strip `Referer` and in-app browsers rewrite params, so the reliable unit is **one distinct link per placement** (WhatsApp status vs. IG bio vs. each ad), with UTM as the human-readable secondary layer. WhatsApp does *not* strip UTM query params in chat, so URL-borne attribution survives.
- **Click → lead → sale funnel, Dub-style [VERIFIED pattern]:** server-side click capture at redirect (ad-blocker-proof), a click ID appended to the destination, lead/sale events keyed to a stable `customerExternalId`. The novel twist for our market: the **"sale event" is a reconciled bank credit** (Layer 3), not a checkout pixel — because most sales pay by transfer, not card. This is the joint that makes bookkeeping and attribution share one customer identity.
- **Ad-platform attribution — stage it, don't over-build [VERIFIED complexity, recommendation UNCERTAIN]:** Google (`gclid`), Meta (`fbclid`/CAPI), TikTok (`ttclid`/Events API, and note `ttclid` expires in only ~7 days — shorter than a transfer sales cycle). Full server-to-server API integration (OAuth review, PII hashing pipelines, per-platform schemas) is **too heavy for v1** for a solo build. Proposed v1 scope: capture + store click IDs and UTMs at click time (cheap, no API), and offer **CSV export in each platform's offline-conversion format** so the merchant/agency can bulk-upload. Live API push is a later phase. **[NEEDS YOUR CALL: is CSV-export-first acceptable, or will target users demand live ad-platform push sooner?]**

---

## 4. The shared spine (why this is one product, not four)

The reason to build all four layers rather than pick one: **they share a single identity chain.**

```
Link/variant  ──click──▶  Customer (lead)  ──sale──▶  Transaction  ──match──▶  Bank feed line
   (Layer 4)               (Layer 4/1)               (Layer 1)              (Layer 3)
```

A click creates or touches a Customer. A reported sale creates a Transaction tied to that Customer and (if known) the originating link. Reconciliation stamps the Transaction `confirmed`. The bookkeeping dashboard, the attribution report, and the "was I paid" check are then three *views* of the same records. Building them on separate models would be the expensive mistake. This is the core architectural claim of the whole proposal.

---

## 5. Data & storage (early-stage appropriate)

- **Events (clicks/conversions): partitioned Postgres table** behind an ingestion interface. [VERIFIED as correct for early scale — ClickHouse/Tinybird only earn their keep at hundreds of millions of rows.] Matches `PRD_V1.md` #4 already.
- **Financial data: integer minor units, per-currency, immutable audit trail** (from `PRD.md` #6). Bank-feed data stored *minimally* — amount, timestamp, counterparty reference only, never full statement history (`PRD_CONVERSION_ATTRIBUTION.md` #3).
- **Reuses the existing Rails 8.1 / Postgres / Hotwire / Solid Queue stack.** No new datastore proposed for v1.

---

## 6. Monetization (the Kippa lesson)

Kippa's apparent failure to monetize a free micro-merchant ledger is the single most important market signal this round. [UNCERTAIN on Kippa specifics, but the risk is real.] A bookkeeping-only subscription for cash-strapped micro-sellers is a hard sell. Candidate revenue lines, none yet validated — this is a discussion, not a plan:

- **Reconciliation/bank-linking as the paid tier** — the "prove you were paid" trust feature is where willingness-to-pay might live, not the ledger itself.
- **Payout/transaction take-rate** later (the `PRD.md` #8 model), which scales with GMV, not seats.
- **Ad-attribution reporting** as a higher tier for sellers who actually run paid ads.

**[NEEDS YOUR CALL: what's the intended money model? It should shape which layer we make "free forever" vs. paid, and therefore what we build first.]**

---

## 7. Regulatory & trust constraints (hard edges, verified)

- **NDPA 2023 + GAID (effective Sept 19, 2025):** bank account numbers, BVN, NIN, phone, address are protected PII; penalties up to ₦10M or 2% of prior-year revenue; AML wants 5-year transaction retention. [VERIFIED] Storing bank-feed data makes us a data controller/processor with real obligations.
- **CBN data-localization directive (June 2026): payment transaction data must be stored in-country, effective Jan 1, 2027.** [VERIFIED, and NEW this round.] **This is a hosting decision we should make now, not after — it directly affects where Stubby runs** (Nigeria-based or compliant hosting) and could force a migration if ignored. Flagging prominently.
- **Bank-linking trust ask:** the market is primed to distrust apps requesting account access (fake loan/investment-app scams). Self-report must remain a complete, non-degraded path. [VERIFIED sentiment, already in `PRD.md` #10.]
- **Meta review walls:** Instagram/Messenger message ingestion requires App Review + Business Verification, reportedly stricter in 2025–26. [VERIFIED] **Recommendation: IG/FB *message* ingestion is a v2/v3 item at best; v1's social surface is the opt-in WhatsApp bot only.** Sharing links *to* IG/FB (Layer 4) needs none of this — only *reading messages* does.

---

## 8. Major corrections to existing PRDs (please reconcile)

1. **[CONTRADICTS EXISTING PRD]** `PRD.md` #3.1/#12 and `PRD_CONVERSION_ATTRIBUTION.md` #7 state "Standardized Open Banking Nigeria APIs went live in August 2025." This round's research indicates the CBN framework was **repeatedly delayed** and is now a **phased rollout across mid-2026 — i.e. possibly still not fully live as of today (July 2026).** [UNCERTAIN — single-stream finding; needs direct verification.] If true, it doesn't change the design (we build against private aggregators Mono/OnePipe/Stitch regardless), but it does change how we *describe* the dependency and how durable we assume it is. **I did not edit the existing PRDs — you should decide the correct wording.**
2. **[CONTRADICTS/UPDATES]** WhatsApp pricing is now **per-template-message with free service conversations** (July 2025), not the per-conversation model the older docs assume. This is *good news* for unit economics and should be reflected.
3. **Kippa status** — the older docs don't mention Kippa's apparent collapse; it's a material competitive/strategic data point worth adding.

---

## 9. A proposed build order (my recommendation, open to challenge)

Sequenced to ship value early and validate the riskiest bets before over-investing:

1. **Layer 1 bookkeeping ledger + web dashboard** — sales/expenses/customers, cash-basis, invoices. Ships standalone value; establishes the shared spine.
2. **Layer 4 link attribution** — reuse `PRD_V1.md` variants; click→customer binding; per-placement analytics. Cheap because the link machinery largely exists.
3. **Layer 2 WhatsApp bot capture** — opt-in Stubby number; numbered-menu logging + payment-proof forwarding. Highest differentiation; gated on Meta verification lead time (start that paperwork early).
4. **Layer 3 reconciliation** — single bank aggregator (Mono first) behind a feature flag, small pilot; fuzzy match + exceptions queue. Validate bank-linking willingness (the existing `RESEARCH_BANK_LINKING_VALIDATION.md` plan) *before* broad rollout.
5. **Ad-platform CSV export** — offline-conversion export for Google/Meta/TikTok. Live API push deferred.

**Riskiest assumptions to validate first, before heavy build:** (a) sellers will link a real bank account [existing research plan covers this]; (b) sellers will move their record-keeping into a new tool at all — the Kippa graveyard says this is hard; (c) the attribution-to-reconciled-sale seam is a real felt need, not just an elegant idea.

---

## 10. Open questions for Victor (I need your calls before going further)

These are the decisions I deliberately did **not** make for you:

1. **Money model.** What's the intended revenue path (reconciliation-as-paid-tier? payout take-rate? ad-reporting tier?)? This determines which layer is free vs. paid and reshapes the build order. (§6)
2. **Ledger depth.** Cash-basis single-entry forever, or a path to double-entry for businesses that grow? Affects the schema from day one. (§3, Layer 1)
3. **Build order / wedge.** Do you agree bookkeeping ledger is the anchor to build first — or would you rather lead with the WhatsApp capture or the attribution story to differentiate faster? (§9)
4. **Ad-platform attribution depth for v1.** Is CSV-export-first acceptable, or do you expect target users to demand live Google/Meta/TikTok API push early? (§3, Layer 4)
5. **OCR.** Drop payment-screenshot OCR for v1 (my recommendation), or keep it? (§3, Layer 3)
6. **IG/FB message ingestion.** Confirm we treat *reading* Instagram/Facebook DMs as out-of-scope for v1 (Meta review wall) and only support *posting links to* those channels — yes? (§7)
7. **Open Banking Nigeria status.** How do you want to reconcile the "live Aug 2025" claim in the existing PRDs with this round's "delayed to mid-2026 phased" finding? Do you want me to verify it directly? (§8)
8. **Hosting / data localization.** Given the Jan 1 2027 in-country payment-data mandate, do you want to lock a Nigeria-compliant hosting decision into the design now? (§7)
9. **Relationship to `PRD_V1.md`.** This is a separate proposal doc as you asked. When/if you adopt it, do you want the shipped v1 link primitives folded in as Stubby's Layer 4, or kept as a distinct product surface?

---

## Sources (research round, July 2026)

Bookkeeping / reconciliation stream: Okra shutdown (Nairametrics); CBN open-banking timeline (TechCabal); Mono developer docs; Kippa funding (TechCrunch) & status (CBInsights, Launch Base Africa, TechCabal); fuzzy-matching reconciliation (Optimus); Nigeria data-protection 2026 (Mondaq); Bumpa tax blog.

Social-commerce ingestion stream: WhatsApp Business pricing (Flowcart, YCloud); WhatsApp Platform (Meta for Developers); Meta Business Verification (respond.io, Landbot); Instagram DM compliance 2026 (Creatorflow, Chatwoot); Bumpa (TechCrunch); Catlog (TechCabal); Kippa unraveling (Launch Base Africa, TechCabal); payment-receipt OCR (Azapi); fake-transfer fraud (financials.com.ng); WhatsApp-first localization & bot UX (Localazy, Landbot).

Attribution / Dub stream: Dub attribution & conversions docs (dub.co); WhatsApp/UTM referrer behavior (digitalmicroenterprise, Branch); Google/Meta/TikTok offline conversion docs; Postgres-vs-ClickHouse at scale (kunalganglani, octabyte); Paystack WhatsApp guide.

*Full URL list retained in the research agents' briefs; reproduce here if this doc becomes canonical.*
