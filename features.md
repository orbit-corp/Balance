# Features Backlog

Candidate features for stubby beyond the core (shorten + redirect). Nothing here is decided or scheduled — each one needs its own brainstorming session (problem, 2+ approaches, trade-offs) before implementation, per the working rule in `CLAUDE.md`. This file exists so ideas don't get lost between sessions.

Grouped by theme. A few entries flag where a feature would conflict with a decision we've already made, since that's exactly the kind of thing worth catching before a session starts rather than mid-implementation.

## Analytics and insights

The foundation for most of this category: every redirect is already a request that hits our server (this is *why* we chose 302 over 301 — a 301 gets browser-cached and we'd stop seeing repeat clicks entirely). The event just isn't captured or persisted yet.

- **Click tracking** — capture timestamp, short_code, referrer, user-agent (parseable into browser/OS/device), and IP-derived coarse geo, per click. Needs to happen async (background job or queue) after the redirect response is sent, not in the request path, or it blows our <100ms latency budget and couples redirect uptime to the analytics pipeline's health.
- **Click dashboards** — aggregated views (clicks over time, top referrers, device/geo breakdowns) built from rolled-up data, not live queries over raw events.
- **UTM / campaign attribution** — let a link carry campaign metadata so clicks can be attributed to a specific marketing effort.
- **Conversion tracking** — webhook or pixel fired on click so customers can tie a click to a downstream action (signup, purchase) in their own systems.
- **Analytics export** — CSV/API access to raw or aggregated click data.
- **Real-time vs batched dashboards** — a genuine trade-off: real-time is more impressive and more expensive (streaming infra); batched (hourly/daily rollups) is cheaper and usually sufficient. Worth an explicit discussion rather than defaulting to real-time because it sounds better.

## Link management

- **Custom aliases** — user-chosen short codes instead of system-generated ones. Already flagged as deferred back when we scoped the functional core; revisit alongside collision handling (a custom alias can collide with an existing one, unlike our counter-based codes which can't).
- **Link editing (change destination)** — let an existing short code point somewhere new. **Conflicts with a standing decision**: our cache-aside layer currently has no TTL because links are immutable — nothing ever changes after creation, so a cached entry never goes stale. Editable links would require either cache invalidation on update or a TTL, which is a real design conversation, not a small tweak.
- **Link expiration** — time-based (link dies after a date) or usage-based (dies after N clicks). Also interacts with the cache: an expired link needs to actually stop resolving, which again pushes on the "immutable, no-TTL cache" assumption.
- **Password-protected links** — require a password before redirecting. Changes the redirect flow from a pure 302 to an intermediate interstitial page.
- **Bulk link creation** — CSV import or a bulk-create API endpoint, useful for marketing teams shortening many campaign URLs at once.
- **Link organization** — folders, tags, or workspaces for grouping links. Depends on accounts existing first.
- **QR code generation** — generate a QR code per short link, common expectation in this product category.
- **Custom link previews (Open Graph)** — control the title/image/description shown when a short link is shared on social media, rather than inheriting whatever the destination page provides.
- **Deep linking** — redirect to a mobile app if installed, otherwise fall back to an app store listing or web page. Meaningfully more complex than a plain redirect (needs platform/device detection and fallback logic).
- **Link-in-bio pages** — a single landing page listing multiple short links, aimed at social media bio use cases. This is really a different product surface (a mini landing-page builder) bolted onto the same short-code infrastructure.
- **A/B testing / split traffic** — same short code randomly resolves to one of several destination URLs by weighted percentage. Requires our lookup to become non-deterministic, which needs care in both the cache layer and the click-tracking model (has to log which variant was served).
- **Geo/device targeting** — same short code resolves differently depending on visitor location or device type.
- **Scheduled activation** — a link that isn't live until a future date, or that deactivates automatically on a schedule.

## Accounts and collaboration

- **User accounts and auth** — prerequisite for ownership, editing, dashboards, and most of the analytics category. Already flagged early on as deferred from the core.
- **Teams/organizations** — shared link libraries across a team rather than per-user.
- **Role-based access control** — who on a team can create, edit, or delete links.
- **API keys** — programmatic access for customers building on top of stubby rather than using the web UI.
- **Audit log** — who created/edited/deleted which link and when. Matters once multiple people can touch the same link.

## Trust, safety, and platform integrity

- **Malicious URL screening** — already tracked in `production_readiness.md`; screen destinations for phishing/malware to keep stubby from being used as an attack vector.
- **Rate limiting** — already tracked in `production_readiness.md`; needed regardless of which paid features ship, since the create endpoint is a public abuse target on its own.
- **Reserved/blocked words** — prevent custom aliases from colliding with system routes or impersonating well-known brands/paths.

## Integrations and extensibility

- **Webhooks** — notify an external system when a link is clicked or created.
- **Third-party integrations** — Zapier, Slack, CRM tools, so click events or link creation can trigger workflows elsewhere.
- **SDKs/CLI** — convenience wrappers around the API for developers.

## Monetization-relevant features

This is the direct answer to "why would anyone pay for this": the redirect itself is a commodity — every competitor gives it away free, including us. Nothing in this section is about the redirect; it's about everything wrapped around it that a paying customer actually values.

- **Custom branded domains** — use your own domain (e.g. `go.yourcompany.com`) instead of a shared stubby domain. Strong brand-trust and click-through-rate driver, commonly a paid-tier feature industry-wide.
- **Tiered usage limits** — free tier capped on link volume/click volume/custom domains; paid tiers raise or remove the caps.
- **White-labeling** — agencies/resellers running stubby under their own brand for their clients.
- **SLA/uptime guarantees** — meaningful for business customers where a broken redirect has real cost; ties back to the durability/availability NFRs we already discussed for the core.

## Revisit if

- Any single feature above starts blocking a real, current need (not hypothetical) — that's the trigger to schedule a proper brainstorming session for it, following the same process we used for the core: problem, 2+ approaches, trade-offs, explicit agreement before code.
- The core (shorten + redirect) is stable enough in production that adding complexity on top no longer risks destabilizing the thing that actually works today.
