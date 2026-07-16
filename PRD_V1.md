# Stubby v1 (MVP) — PRD

**Scope:** Everything before the sale — create, brand, share, and measure links. No conversion tracking, no billing, no payouts (v2+).
**Target user:** African SMEs and creators selling via WhatsApp/Instagram/SMS, operating entirely from a phone.
**Positioning:** "Know which link is working — on 3G, on WhatsApp, on your phone."
**Riskiest assumption this MVP tests:** *an African seller will create tracked links per audience, check the dashboard, and come back weekly.* Every feature below serves that loop; everything else is deferred (see "Deferred to v1.1" — ideas preserved, not discarded).
**Status:** Each feature is self-contained; approach/design to be researched and agreed before implementation.

---

## 1. Accounts & Workspaces

- Email + password signup (verified) and Google OAuth.
- Single-user workspaces in v1 — no member invites; schema keeps `workspace_id` on everything so teams bolt on later without migration pain.
- Free tier limits: 25 links/mo, 1,000 tracked clicks/mo, 30-day analytics retention.
- **Why:** everything hangs off identity; limits protect domain reputation.

## 2. Link Management

- Create/edit/archive/delete links; editable destination (link keeps working when catalog changes).
- Custom slugs (`stub.by/serum`) with reserved-word list.
- Tags + search + filter.
- Expiration date with optional fallback URL.
- Plain UTM fields on the link form (no saved templates in v1).
- **Why:** the jump from one-shot shortener to a tool a business relies on.

## 3. Redirect Engine

- 302 redirects (preserves analytics).
- Cache-first lookup (Solid Cache/Redis).
- Latency: **measure** p95 from Lagos & Nairobi from day one; alert at > 300ms. Host in af-south-1 or Europe; < 50ms p95 is the v2 SLO, not a v1 gate.
- Multi-domain routing from day one: lookup by `(host, slug)`, unique index on the pair — even though v1 serves only Stubby-owned domains.
- Rate limiting on creation and redirect endpoints.
- **Why:** redirects are the product; single-domain assumptions are miserable to retrofit.

## 4. Click Analytics

- **Store everything** per click from day one: timestamp, country/city, device, OS, browser, referrer, bot flag, trigger (link vs QR). Storage is cheap; UI is not.
- Dashboard shows only the wedge: clicks over time, top links, **channel filter** (WhatsApp / Instagram / Facebook / TikTok / X / SMS-or-direct / other; referrer + UA heuristics; UI is honest that WhatsApp/SMS arrive referrer-less), and **variant comparison**.
- Country/device/browser breakdown UIs deferred — the data will already be there.
- Storage: partitioned Postgres events table behind an ingestion interface (swappable for ClickHouse later).
- **Why:** attribution is the wedge; channels are how African sellers think.

## 5. Link Variants (per-audience attribution) — THE core feature

- One destination → N tracked links in one action ("duplicate for: Tola, Kemi, SMS blast").
- Variants grouped in the dashboard with side-by-side comparison.
- **Why:** referrers are stripped by WhatsApp/SMS; deciding attribution up front via separate links is the reliable mechanism. If v1 shipped only three things, this is one of them.

## 6. WhatsApp-Native Links

- Click-to-WhatsApp composer: build a tracked link wrapping `wa.me/<number>?text=<prefill>`.
- Per-variant prefill text with an auto-inserted ref tag (e.g. "(ref: TOLA)") so attribution lands inside the seller's chat.
- Custom link preview (OG title/description/image) with a live "how it renders in WhatsApp" preview.
- **Why:** WhatsApp is the #1 sales channel in every beachhead market; no incumbent treats it as first-class.

## 7. QR Codes

- Per-link QR: plain black-and-white PNG download.
- Scans tracked as `qr` trigger, filterable in analytics (the tracking is the feature; styling is not).
- **Why:** offline-to-online bridge (packaging, posters, market stalls); cheap, disproportionately valued.

## 8. Trust & Anti-Abuse

- Google Safe Browsing check at creation + periodic re-scan; auto-disable malicious links.
- Anonymous (no-account) shortening removed.
- Progressive limits: unverified accounts get minimal quotas; email verification unlocks the standard free tier. (Phone/OTP tier deferred — at MVP scale, manual review + rate limits suffice and OTPs cost money.)
- `/preview/:slug` public page showing destination before redirect.
- Abuse report endpoint; takedown SLA < 4h.
- Destination denylist (configurable categories).
- **Why:** shortened links = scams in this market; a blocklisted shared domain kills every customer at once. Non-negotiable in v1.

## 9. Onboarding & Activation

- Signup lands directly in "create your first WhatsApp link," with variant suggestions inline.
- Target: first tracked link shared within 5 minutes of signup.
- Copy/share actions target the WhatsApp share sheet first.
- **Why:** activation — not acquisition — is the MVP bottleneck; for this product, onboarding is a feature, not chrome.

## 10. Instrumentation & Feedback

- Funnel events on Stubby itself: signed up → created link → link got first click → created a variant → returned week 2.
- A WhatsApp group/line for beta users (support + feedback in the channel they live in).
- **Why:** the MVP's output is learning; without instrumentation the result can't be read.

## 11. Mobile-First UX (cross-cutting)

- Every flow (signup → create → analyze) fully usable on a low-end Android over 3G.
- Server-rendered Hotwire pages; page-weight budgets enforced (< 150KB); test on throttled connections.

---

## Deferred to v1.1 (ideas preserved — do not lose these)

- **Mini bio page + one-click Linktree import.** The acquisition hook (Linktree's 12% cut / price hikes = active switching moment): avatar, ordered links, WhatsApp CTA, "⚡ Powered by Stubby" badge growth loop, < 150KB page. Deferred because it's a second product surface and acquisition isn't the MVP bottleneck.
- **Branded subdomains** (`ada.stub.by` free per workspace): wildcard DNS + wildcard cert, same host-routing code path (already built in §3). Requires reserved-name policing (banks, brands) and claim verification — an abuse surface not worth defending pre-traction.
- **Bulk CSV link creation** (SMS campaign workflow — pairs with future SMS-provider integrations).
- **Workspace member invites** (owner/member roles; agency + team personas).
- **UTM saved templates** (agency persona).
- **QR customization** (colors, center logo, SVG export).
- **Analytics breakdown UIs** for country/device/browser (data already captured from day one).
- **Shareable read-only stats pages** (off by default).
- **Phone/OTP verification tier** for higher quotas; also phone-number sign-in for email-light users.
- **< 50ms redirect p95 from Lagos/Nairobi** as a hard SLO (edge/African POP work).

## Non-Goals (v1 and v1.1 — see master PRD for phasing)

Conversion/sales tracking, affiliate programs, payouts, billing/plans (v1 is free beta), BYO custom domains, API & webhooks, geo/device targeting, A/B testing, password-protected links, SMS-provider integrations, localization beyond English.

## Success Criteria

- **Activation:** median time signup → first shared link < 5 min; ≥ 60% of signups share a link day one.
- **Retention (the real test):** ≥ 30% of activated users return in week 2.
- ≥ 30% of active users create link variants or WhatsApp links (validates differentiation).
- % of clicks classified WhatsApp (validates channel thesis).
- Redirect p95 alert threshold 300ms (Lagos/Nairobi); uptime ≥ 99.9%.
- Malicious-link rate < 1% of created links; median takedown < 4h.

## Suggested Build Order

1. Accounts & workspaces → 2. Link CRUD → 3. Redirect engine + click events (one unit; trust layer woven in from here, not bolted on) → 4. Variants + WhatsApp composer → 5. Dashboard (time series, top links, channel, variant comparison) → 6. Onboarding flow + instrumentation → 7. QR.
