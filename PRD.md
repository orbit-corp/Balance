# Stubby — Product Requirements Document

**Version:** 0.2 (draft — Phase 1/2 reconciled with `PRD_V1.md`, which is authoritative for v1 scope)
**Date:** July 2026
**Author:** Victor (drafted with Claude)
**Status:** For review — per project rules, no feature in this document is approved for implementation until explicitly agreed.

---

## 1. Vision

**Stubby is link, attribution, and affiliate-payout infrastructure for Africa's WhatsApp-and-SMS-first commerce economy.**

Dub.co started as a link shortener and evolved into an end-to-end partner/affiliate marketing platform (conversion tracking → commissions → payouts → fraud → partner discovery). Stubby follows the same arc, but rebuilt around the realities global tools ignore:

- Billing in **local currency via Paystack/Flutterwave/mobile money** (USD Stripe billing structurally fails in Nigeria — naira cards were capped at $20–50/month of international spend for years, and even after the mid-2025 partial resumption, quarterly caps and decline rates make dollar subscriptions unreliable).
- Affiliate **payouts to M-Pesa, MTN MoMo, and local bank accounts** (dub pays out via Stripe Connect, PayPal, Tremendous, and stablecoin — none of which reliably reach African partners; this is dub's single clearest whitespace).
- **WhatsApp and SMS as the primary distribution surfaces**, not the browser (WhatsApp is the #1 platform in Nigeria, Kenya, Ghana, and South Africa; SMS retains ~98% open rates; 63.5% of African mobile-money volume still runs over USSD).
- A **trust and anti-abuse layer as a first-class product feature**, because in this market shortened links are widely associated with scams (Safaricom actively trains customers to distrust them) and a burned domain reputation is existential.

**Positioning in one line:** *not a cheaper Bitly — the tool that lets African businesses and creators prove which link made the sale, and pay the person who shared it.*

---

## 2. Market Opportunity (research summary)

Full research brief with sources is available separately; the load-bearing facts:

### Why now
- Africa's creator economy is growing at high-20s % annually (estimates range $5.1B–$18B in 2025–26 depending on definition — treat directionally, not as a single anchor number).
- Influencer marketing spend grows ~25%/yr, yet **73% of influencer campaigns fail to deliver measurable results** and "difficulty measuring performance" is the #1 brand complaint. Attribution is the unmet need — shortening is a commodity.
- Affiliate behavior already exists at scale in Nigeria: **Expertnaire charges affiliates ₦10,000/yr just to join** (proof of willingness to pay), Stakecut pays weekly, Jumia's KOL program pays 4–13%. **Selar paid ₦9.8B to 241K creators in 2024.** The behavior is proven; the tooling (tracking, analytics, multi-merchant programs, payouts) is primitive.
- TikTok's monetization programs exclude Nigeria entirely — African creators monetize via brand deals, affiliate links, and selling their own products. **Link infrastructure is their payout rail.**
- Incumbents are actively alienating this market (2025–26): Bitly put ad interstitials on free links; Linktree takes a 12% cut of digital sales on the free plan; all price in USD ($29/user/mo Bitly Growth ≈ ₦44,000 — near Nigeria's monthly minimum wage) with no mobile-money billing.
- The Africa-focused link/attribution niche appears **open**: Disha (Nigerian link-in-bio, 100K creators) was shut down by Flutterwave in 2024; Mainstack and Selar compete on storefronts, not on link management/attribution/affiliate infrastructure.

### Beachhead sequence
1. **Nigeria** — largest creator/SME base, strongest existing affiliate culture, worst payments friction (highest differentiation), 107M internet users.
2. **Kenya** — M-Pesa payout rails (Daraja B2C API), high WhatsApp/SMS commerce, 88% banked.
3. **South Africa** — highest ARPU and largest e-commerce value ($38.5B, 2025), but most regulated (POPIA opt-in direct marketing) and most contested by global SaaS.
4. Ghana opportunistic; **Egypt deferred** pending dedicated research (payments/channel data was thin; needs Fawry/InstaPay/Vodafone Cash investigation and Arabic localization).

### Market constraints that shape the product
- 54% smartphone adoption in SSA; 40%+ of connections are still feature phones. Data affordability remains a real constraint (SSA users spend ~2.4% of monthly income per GB).
- Currency volatility is extreme (naira ₦471→₦1,529/$ in two years; cedi swung –24% then +30–40%). Pricing must be local-currency, reviewed quarterly.
- Three data-protection regimes apply from day one: Nigeria NDPA 2023 (+GAID directive, effective Sept 2025), Kenya DPA 2019, South Africa POPIA. Click tracking and conversion attribution are personal-data processing under all three.

---

## 3. Target Users

| Persona | Description | Primary jobs |
|---|---|---|
| **The WhatsApp seller** | SME selling via WhatsApp catalog + Instagram discovery, paid via bank transfer/M-Pesa/Paystack link. ~90% of SSA businesses are SMEs; most have no website. | Short branded links for broadcasts and bio; know which channel (WhatsApp vs IG vs SMS) drives orders; QR codes for packaging/market stalls. |
| **The creator/affiliate** | Nigerian/Kenyan creator monetizing via affiliate links and own digital products (Selar/Expertnaire user). Often mobile-only. | One bio page; trackable links per campaign; get paid commissions to mobile money without a PayPal account. |
| **The digital marketer / agency** | Runs influencer + SMS + WhatsApp campaigns for brands. Suffers the "73% unmeasurable" problem. | Per-creator attribution; UTM discipline; client-facing reports; bulk link creation. |
| **The merchant with an affiliate program** | E-commerce/digital-product/fintech business that wants Jumia-KOL-style referrals without building payout infra. Stubby's Business-tier buyer. | Recruit partners, set commission rules, track conversions, pay out across countries, catch fraud. |
| **The developer/fintech (later)** | Needs link/QR/attribution APIs (e.g., banks generating payment links, SMS providers). | REST API, webhooks, high-volume link creation. |

---

## 4. Current State of Stubby (baseline)

Rails 8.1 monolith (PostgreSQL, Hotwire, Tailwind, Solid Queue/Cache/Cable, Kamal deploy). Implemented today: anonymous link creation (`POST /links`), base62 short codes from DB auto-increment, 302 redirect, URL validation, clipboard copy. **One table (`short_links`), no auth, no analytics, no billing.** Everything below is net-new. The existing `features.md`, `production_readiness.md`, and `interest.md` docs remain the low-level design references; this PRD sets product scope and sequencing above them.

---

## 5. Product Scope & Phasing

Sequencing principle: **dub's history is the map** — links → analytics → conversions → partners — but Stubby pulls trust/anti-abuse and Africa-native channel features *forward* (they're existential here, not enhancements), and pushes deep-linking/enterprise features *back*.

### Phase 1 — MVP (authoritative spec: `PRD_V1.md`)
*Goal: validate the core loop — an African seller creates tracked links per audience, checks the dashboard, and comes back weekly. Free beta, fully usable from a phone.*

Scope summary; `PRD_V1.md` carries the full feature spec, deferred list, and build order.

**1.1 Accounts & workspaces** — email + password (verified) and Google OAuth. Single-user workspaces in v1 (schema keeps `workspace_id` on everything so teams bolt on later). Free tier: 25 links/mo, 1,000 tracked clicks/mo, 30-day retention — generous enough to be usable (data costs make trial friction fatal), bounded to protect domain reputation (§7).

**1.2 Link management** — CRUD with editable destinations, custom slugs (reserved-word list), tags/search/filter, expiration with fallback URL, plain UTM fields (saved templates deferred).

**1.3 Redirect engine** — 302s (preserves tracking), cache-first lookup, multi-domain `(host, slug)` routing from day one (single-domain assumptions are miserable to retrofit), rate limiting on creation and redirects. Latency: **measured** from Lagos/Nairobi with alerting at >300ms; <50ms p95 is the Phase 2 SLO, not a v1 gate.

**1.4 Click analytics** — full event capture **stored** from day one (timestamp, country/city, device, OS, browser, referrer, bot flag, trigger); dashboard limited to the wedge: time series, top links, channel filter (WhatsApp / Instagram / Facebook / TikTok / X / SMS-or-direct / other, via referrer + UA heuristics; UI is honest that WhatsApp/SMS arrive referrer-less), and variant comparison. Partitioned Postgres events table behind an ingestion interface (ClickHouse/Tinybird-swappable later).

**1.5 Link variants** — one destination → N tracked links in one action ("duplicate for: Tola, Kemi, SMS blast") with side-by-side stats. **The core attribution feature**, pulled forward from the old Phase 2: referrer-stripping on WhatsApp/SMS makes pre-decided per-audience links the only reliable attribution mechanism.

**1.6 WhatsApp-native links** — click-to-WhatsApp composer (`wa.me` + prefilled text) with per-variant ref tags so attribution lands inside the seller's chat; custom OG previews with a live "how it renders in WhatsApp" preview. Pulled forward: this is the differentiation, and it's pre-sale.

**1.7 QR codes** — plain black-and-white PNG per link; scans tracked as a distinct trigger (styling deferred; the tracking is the feature).

**1.8 Trust & anti-abuse** — Safe Browsing scan at creation + periodic re-scan with auto-disable; **anonymous shortening removed**; progressive limits keyed to email verification; public `/preview/:slug`; abuse reporting with <4h takedown SLA; destination denylist. See §7.

**1.9 Onboarding, activation & instrumentation** — signup lands directly in "create your first WhatsApp link" (target: first tracked link shared within 5 minutes); funnel events on Stubby's own activation/retention loop; a WhatsApp group for beta users.

**Explicitly out of Phase 1** — deferred to v1.1 with rationale preserved in `PRD_V1.md`: bio pages + Linktree import, branded subdomains, bulk CSV creation, workspace member invites, UTM templates, QR customization, analytics breakdown UIs, shareable stats pages, phone/OTP sign-in and verification tier, hard latency SLO. Still Phase 2+: custom domains, password-protected links, geo/device targeting, A/B testing, API, billing.

---

### Phase 2 — Monetization + growth surfaces
*Goal: convert validated v1 usage into revenue (naira-first billing), and widen acquisition with the deferred v1.1 growth features. (WhatsApp-native links and variants moved to Phase 1 — they are the differentiation and are pre-sale.)*

**2.1 Growth surfaces (v1.1 — deferred from MVP, specs preserved in `PRD_V1.md`)**
- **Bio pages (link-in-bio):** one mobile-first, low-bandwidth page per workspace — avatar, headline, ordered Stubby links, WhatsApp CTA; every item click tracked as a normal link click; "⚡ Powered by Stubby" badge as the growth loop (removal becomes a paid feature). Includes **one-click Linktree import** (paste URL → links scraped → page live) to harvest the active switching moment created by Linktree's 12% sales cut and price hikes. Deliberate scope creep beyond dub; kept minimal — Stubby is not becoming a website builder.
- **Branded subdomains:** every workspace claims `ada.stub.by` free (wildcard DNS + wildcard cert; same host-routing code path built in Phase 1). Needs reserved-name policing (banks, brands) and claim verification. Middle rung of the domain ladder: shared domain (free) → branded subdomain (free, verified) → custom domain (paid, §2.3).
- **Smaller v1.1 items:** workspace member invites (owner/member roles), UTM saved templates, QR customization (colors/logo/SVG), analytics breakdown UIs (country/device/browser — data captured since day one), shareable read-only stats pages, phone/OTP sign-in + verification tier for higher quotas.

**2.2 SMS-oriented features**
- Ultra-short primary domain (5–7 chars total) — SMS is billed per 160-char segment; link length is a direct cost line for bulk senders.
- Segment-count calculator in the link composer.
- Integrations with African bulk-SMS providers (Africa's Talking, Termii) to inject tracked links into campaigns. (Stubby does **not** send SMS itself — it makes links for people who do. Keeps NCC/sender-ID/POPIA liability with the sender.)
- Bulk link creation via CSV upload (deferred from MVP; SMS campaign workflows need hundreds of links at once).

**2.3 Custom domains**
- Bring-your-own domain (CNAME + auto-TLS). Branded domains are both an upsell **and** the core trust mechanism (§7): `yourbrand.ng/x` beats `stub.by/x` in a scam-wary market.
- Per-domain default fallback URL and 404 page.

**2.4 Billing (the make-or-break feature)**
- **Paystack as primary gateway** (highest success rates in Nigeria; supports cards, bank transfer, USSD, mobile money). Flutterwave as the multi-country second (Kenya/Ghana expansion). Stripe only for diaspora/global customers.
- **Price in local currency** (NGN first; KES/ZAR/GHS at country launch). Quarterly price review with an explicit policy (local guidance: adjust 5–7% when currency slips >10%).
- Dunning designed for African card reality: failure is normal, not exceptional. Retry across methods, offer bank-transfer/USSD fallback, in-app wallet/prepaid balance, generous grace periods, and annual-prepay discounts (which also hedge FX).
- Proposed plans (NGN anchors, to be validated):
  - **Free** — 25 links/mo, 1K clicks/mo, bio page, QR, 30-day retention.
  - **Starter ~₦5,000/mo** (≈$3–4) — 500 links/mo, 25K clicks, custom domain ×1, WhatsApp/SMS features, 1-year retention. Priced for the creator/SME, an order of magnitude under Bitly.
  - **Business ~₦25,000/mo** (≈$16) — 5K links/mo, 250K clicks, 5 domains, 5 seats, API access, conversion tracking (P3), affiliate program (P3), 3-year retention.
  - **Scale/Enterprise** — custom; agencies, fintechs, high-volume API.

**2.5 Public API (v1) + webhooks**
- Token-authenticated REST API: link CRUD, QR, analytics summary. Webhooks: `link.created`, `link.clicked` (batched). Full OAuth app platform deferred.

---

### Phase 3 — Attribution & affiliate programs (the moat)
*Goal: from "which link got clicks" to "which link/person made the sale — and pay them."*

**3.1 Conversion tracking**
- Click ID (`stub_id`) set as a cookie/query param at redirect for web destinations; lightweight JS snippet + server-side track API to record **leads** and **sales** (amount, currency) attributed to the click. Only reaches the minority of sales that touch a checkout page (§12) — most closes in DMs, hence the mechanism below.
- **WhatsApp reconciliation bot as the flagship** conversion source for the dominant bank-transfer-paid, DM-closed case: a Stubby-operated WhatsApp Business number the seller messages into — no access to the seller's own inbox required, which sidesteps Meta App Review and the WhatsApp-Business-app-vs-Cloud-API migration wall entirely. Seller forwards a payment-proof screenshot and indicates the link/variant it belongs to; OCR extracts amount and approximate timestamp as a match candidate against the seller's linked bank feed (below). This is bookkeeping reconciliation applied to attribution, not surveillance of chat content.
- **Open-banking account linking (Mono/Okra-style aggregator) as the confirmation source:** merchant links their bank account; the OCR candidate above is matched against real transactions (amount + date-window fuzzy match). Matched → conversion marked **confirmed**; unmatched → stays **self-reported**, still recorded (extends §12's "unattributed bucket is first-class" principle: confirmation status is itself honest metadata, not something to force). Near-ties (two similar-sized sales close in time) fall into an exceptions queue for the seller to resolve, not an auto-guess.
  - Caveat: Nigeria's CBN open-banking framework isn't fully live yet (phased rollout expected from early 2026); Mono/Okra today run proprietary bank connections ("open finance"), not the finished regulated standard. Build against their current APIs; revisit if/when the CBN registry model activates.
  - Caveat: this asks sellers for their most sensitive credential yet — bank account access, in a market primed to distrust apps that ask for exactly that (fake loan/investment-app scams are common). Validate willingness with real beta users before this becomes load-bearing (see §10, §11).
- Paystack webhook integration retained as a secondary, simpler confirmation source for sellers who do use checkout links (`charge.success` matched to click IDs); Flutterwave next. CSV upload remains the fallback for anyone who doesn't use the bot.
- Customer records tying clicks → leads → repeat sales (dub's `Customer` model, simplified).

**3.2 Affiliate/partner programs**
- A workspace can create a **Program**: commission rules (percentage or flat, per sale/lead/click; optional recurring months cap), branded join page, terms.
- Partners (creators/affiliates) get a partner dashboard: their links, clicks, conversions, pending/paid earnings. Partner profiles are cross-program (one Stubby partner identity, many programs — dub's model, and the seed of a future network).
- Enrollment lifecycle: apply → approve/reject; per-partner auto-generated links; approval workflows kept simple at first (no groups/tiers/bounties yet).
- Commission lifecycle: pending → (holding period 0–30 days, merchant-configurable) → payable → paid; refund claw-back.

**3.3 Payouts — the single most defensible feature**
- Payout methods: **mobile money (M-Pesa via Daraja B2C, MTN MoMo), Nigerian bank transfer (Paystack/Flutterwave transfer APIs), and later stablecoin/USD wallet** for cross-border. Evaluate a pan-African disbursement aggregator (PawaPay, Kora, Flutterwave Payouts) vs direct integrations — aggregator first for coverage, direct for margin, likely.
- Merchant funds payouts via wallet top-up (bank transfer/card); Stubby disburses and takes a **payout fee (~5%, dub's default)** — this is a revenue line, not just plumbing.
- Minimum payout thresholds, payout statements, failure handling (mobile-money name-mismatch and wallet-limit failures are common; build retry + resolution flows).
- KYC on partners before first payout (tiered: BVN/phone verification in Nigeria, ID upload beyond thresholds) — required by payment partners and core to fraud defense.

**3.4 Fraud (v1)**
- Self-referral detection (customer email/phone/device matches partner), click-flooding and bot filtering, duplicate-account heuristics, commission `hold` status with a review queue. Dub's recent commit history is dominated by fraud/holds — they learned this the hard way at scale; Stubby should ship the basics *with* payouts, not after the first incident.

---

### Phase 4 — Deepening (post-PMF, directional only)
- Partner discovery/network (two-sided marketplace: merchants find proven African affiliates — dub's Network, but with local supply as the moat).
- Geo/device targeting, A/B testing, password-protected links, deep links (app routing matters less in a WhatsApp-first market — deliberately late).
- Embedded referral widgets (Selar-style "refer & earn" inside merchant apps).
- Agency/client sub-accounts and white-label reports.
- Additional integrations: Shopify (SA market), Jumia sellers, Zapier/Make.
- Local-language localization (Swahili, Hausa, Yoruba, Pidgin, French for WAEMU, Arabic for Egypt).

---

## 6. Non-Functional Requirements

- **Mobile-only capable.** Every workflow — signup, link creation, analytics, payout setup — must be fully usable on a low-end Android phone. Hotwire server-rendered pages are actually an advantage here vs heavy SPAs; enforce page-weight budgets (<150KB initial load target) and test on throttled 3G.
- **Redirect availability & latency are the product.** ≥99.9% redirect uptime in v1; 99.95%+ once paid plans launch. Latency measured from Lagos/Nairobi with alerting at >300ms; p95 <50ms becomes the SLO in Phase 2. Redirect path must survive app/database incidents (cache-first lookup, graceful degradation).
- **Data protection compliance from day one:** NDPA (Nigeria — register with NDPC if classified "controller of major importance"; 72-hour breach notification; annual audit returns), Kenya DPA (ODPC registration, DPIAs), POPIA (SA — strict opt-in direct marketing affects Stubby's own lifecycle emails and customers' campaigns). Practical requirements: IP truncation/hashing option for analytics, data-retention windows per plan, DPA template for Business customers, and a data-residency answer (at minimum: documented transfer mechanism; evaluate af-south-1 / Lagos hosting).
- **Money correctness:** all amounts in integer minor units; per-currency ledgers; immutable commission/payout audit trail; idempotent webhook processing.
- **Observability:** structured logging, error tracking, and redirect/latency dashboards before Phase 2 (per `production_readiness.md`).

---

## 7. Trust & Anti-Abuse (cross-cutting, existential)

Shortened links in Africa are synonymous with phishing (documented scam waves in Kenya, Nigeria, Namibia; carriers filter aggressively; WhatsApp bans domains wholesale). **If Stubby's shared domain gets blocklisted by a carrier or WhatsApp, every customer's links die at once.** Therefore:

1. **Anonymous shortening is removed at launch** (decided — formerly Open Question #2): all link creation requires a verified account, with progressive limits keyed to verification level.
2. **Destination scanning** (Safe Browsing + heuristics + periodic re-scan; malicious links auto-disabled) with an abuse-report → takedown SLA (<4h target).
3. **Reputation isolation:** push paying customers to branded custom domains; consider separate shared domains per risk tier so free-tier abuse can't burn paid users.
4. **Progressive limits:** unverified accounts get minimal quotas; verification (email → phone → KYC) unlocks volume.
5. **Transparency as a feature:** public `/preview/:code`, verified-business badges on bio pages and previews.
6. Blocked-destination policy (gambling/crypto-scam categories configurable per country regulation).

---

## 8. Business Model Summary

Three revenue lines, sequenced:
1. **SaaS subscriptions** (Phase 2) — local-currency tiers, Paystack/Flutterwave billing. Primary early revenue.
2. **Payout fees** (Phase 3) — ~5% on affiliate disbursements (mirrors dub; also how Selar/Expertnaire monetize). Scales with GMV, not seats — the long-term engine.
3. **Usage/API overage** (Phase 3+) — event-based pricing for high-volume API/fintech customers.

Unit-economics watch-items: Paystack fees (1.5% + ₦100 local) on small subscription amounts; SMS/OTP verification costs; FX exposure on any USD-denominated infra (hosting, Redis, email) against NGN revenue — revisit pricing quarterly.

---

## 9. Success Metrics

| Phase | North star | Guardrails |
|---|---|---|
| P1 | Activation (median <5 min to first shared link; ≥60% share day one) and week-2 retention ≥30%; % of clicks from WhatsApp (channel thesis) | Redirect p95 (alert >300ms); abuse takedown time; % links flagged malicious |
| P2 | Paying workspaces; MRR in NGN; billing success rate (target >85% first-attempt across methods) | Churn from payment failure vs. choice; free→paid conversion |
| P3 | GMV tracked (attributed sales); payout volume; take-rate revenue | Payout success rate (>95%); fraud rate on commissions (<2%); time-to-first-payout |

---

## 10. Key Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Shared domain blocklisted (WhatsApp/carrier) | Existential | §7 in full; custom domains; risk-tiered shared domains |
| Payment failure kills conversion to paid | High | Multi-method billing, wallet balance, annual prepay, dunning-by-design |
| dub (open source, well-funded) localizes for Africa | Medium | Speed + payments/payout integrations + local trust/brand are the moat, not features; dub's stack (PlanetScale/Tinybird/Stripe) is US-centric and their focus is upmarket enterprise partners |
| FX volatility erodes NGN-denominated margin | Medium | Quarterly repricing policy; USD-linked Scale tier; cost base review |
| Affiliate fraud drains merchant trust | High | Holds + KYC + fraud v1 shipped *with* payouts (Phase 3), not after |
| Regulatory (NDPA/POPIA) enforcement | Medium | Compliance-by-design (§6); local counsel per country before payout launch |
| Solo-builder scope explosion | High | Phases are strict gates; Phase 4 is directional only; bio pages capped in scope |
| Sellers won't link real bank accounts for conversion confirmation (§3.1) | Medium–High | Manual self-report (§12) remains the baseline path regardless; validate bank-linking willingness with beta users before treating it as load-bearing; open banking (Mono/Okra) still pre-regulatory in Nigeria as of 2026 |

---

## 11. Open Questions (for Victor)

1. **Wedge order:** launch P1 as a general link manager, or lead with the creator/affiliate story from day one (P1+P3-lite for a single niche, e.g., Selar-style digital-product affiliates)? This PRD assumes the former; the latter is faster to differentiation but skips revenue-simple SaaS.
2. **Anonymous shortening — RESOLVED:** removed at launch; all creation requires a verified account (see §7 and `PRD_V1.md` §8).
3. **Company/legal domicile and payment-provider onboarding** (Paystack business account requirements, and later disbursement licenses/partnerships) need early legwork — payout features have regulatory lead time.
4. **Domain acquisition:** the ultra-short brandable domain (§2.2) should be secured before public launch.
5. Pricing anchors in §2.4 are hypotheses — validate against 10–20 target users in Lagos/Nairobi before Phase 2 build.
6. **Open-banking reconciliation (§3.1, §12) is unvalidated on two fronts:** whether sellers will actually link real bank accounts to a link-tracking tool, and whether to build against Mono/Okra's current proprietary APIs or wait for CBN's open-banking registry (phased rollout expected from early 2026). Test with beta users before Phase 3 build.

---

## 12. Conversion Attribution Honesty (decided July 2026; automated path revised July 2026)

Context: conversion tracking (a slice of §3.1) is being pulled forward — click counts alone don't serve the wedge. Mechanism decided: `stub_id` click ID + ref-tag carrier + **manual conversion marking**, captured through a Stubby-operated WhatsApp reconciliation bot (seller forwards payment-proof + link reference) rather than a generic web form — meets the seller in the channel they already close sales in. Automated paths were evaluated: cookie/JS dies at the WhatsApp jump; payment-link-in-path dies on buyer behavior (buyers pay by direct bank transfer, not payment links); Paystack dedicated virtual accounts die on the 1,000-account cap, KYC lead time, and added product complexity — rejected. **Open-banking account linking (Mono/Okra-style) is the candidate automated confirmation path**, superseding DVAs: it reconciles the seller's self-reported payment proof against their real bank feed rather than requiring the buyer to pay through a Stubby-controlled rail, which fits how this market actually pays (§3.1 for detail, including the regulatory-maturity and bank-trust caveats).

Manual marking presumes the seller knows which link produced the sale. That knowledge exists only when the buyer arrives *carrying a mark*, so attribution quality is decided at link-creation time, by destination type:

- **WhatsApp-destination links (strong path):** the per-variant ref tag in the prefill text (§1.6) is the carrier — the buyer's first message delivers "(ref: TOLA)" into the seller's chat, where the sale closes. Leak: prefill is editable; mitigate by making the tag useful ("the ankara dress, from Tola's page"), not bureaucratic.
- **Web destinations:** `stub_id` query param works only if a checkout catches it — rare in a bank-transfer market.
- **No carrier (buyer DMs cold, days later):** genuinely unattributable by any system.

**Principle — the unattributed bucket is a first-class outcome.** Every conversion-recording surface (WhatsApp bot, CSV import) must offer "I don't know which link." Forcing every sale onto a link fills per-link revenue with guesses and rots the data the same way raw click counts did; honest gaps keep the attributed numbers trustworthy. The unattributed share is itself a metric: a high share tells the seller to put ref-tagged links on more surfaces — and tells Stubby how much selling is happening outside the strong path.

**Corollary — confirmation status is honest metadata too.** Bank-feed reconciliation (§3.1) doesn't replace self-report; it grades it. A matched conversion is **confirmed**; an unmatched one stays **self-reported**, not discarded or force-matched. Treat "% confirmed" the same way as the unattributed share — a diagnostic of how much of the seller's revenue picture is verified vs. taken on trust, not a gate for whether a sale counts.
