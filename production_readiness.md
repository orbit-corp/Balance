# Production Readiness Backlog

Concerns identified during design discussions that aren't part of the current core design (shorten + redirect, no auth, no analytics) but should be brainstormed before stubby is considered production-grade. Nothing here is decided — this is a list of topics to come back to, not a spec.

## Rate limiting

The create endpoint is public and unauthenticated (no accounts yet), which makes it an easy target for abuse — spam link creation, scraping the ID space, or just flooding writes. Needs a brainstorming session on: per-IP vs per-token limits, what a reasonable threshold looks like given our ~1000 rps read-peak / 1000:1 read:write assumption, and where the limiter lives (app-level middleware vs. a dedicated layer like a reverse proxy or Rack middleware/gem).

## Observability

No metrics/logging strategy exists yet. At minimum, production operation needs visibility into: cache hit/miss rate (validates whether cache-aside is actually paying off), redirect latency (are we holding the <100ms target under real load), error rates (failed creates, 404 rate on redirects), and DB/Redis health. Needs a decision on tooling (e.g. structured logs, a metrics backend) and what "healthy" looks like before this is meaningful.

## Input validation beyond "is it a valid URL"

Current validation only checks that the submitted string is a well-formed URL. Production-grade needs a decision on whether to screen for malicious targets — open redirects, phishing domains, or other abuse of stubby as a redirect vector. This is a real trade-off between safety and staying a simple, fast shortener; needs explicit discussion on how far to go.

## Deployment and infra

No decisions yet on how the DB and Redis are provisioned, backed up, or monitored in production (this connects to [[redis-incr-counter-with-aof]] in `interest.md` re: Redis persistence). Needs a session on hosting choice, backup/restore strategy, and what monitoring/alerting exists for both stores.

## Revisit if

- Any of the above becomes urgent because of an actual incident (abuse, outage, data loss) rather than being addressed proactively.
- The core design (functional + non-functional requirements, schema) is fully implemented and stable enough to layer these on top.
