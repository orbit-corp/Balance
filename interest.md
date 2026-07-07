# Interest / Revisit Later

Ideas we deliberately deferred during design discussions. Not decisions — just parked for future review.

## Dedup on URL shortening (deferred 2026-07-06)

**Decision made:** No dedup for v1 — every shorten request creates a new short code, even for a long URL that's already been shortened before.

**The alternative (dedup):** Same long URL always maps to the same short code. Before creating a new short link, look up whether the long URL already exists (via a hash index, e.g. SHA-256 of the URL, since indexing raw long-text URLs directly is expensive) and return the existing code if found.

**Why deferred:**
- Adds a lookup-before-write on every create (no longer O(1) insert).
- Gets messy once accounts/ownership exist: if two users shorten the same URL, do they share one short code? If so, who owns it, and can one user's delete break the other's link? Would need a join table (users ↔ short_links) instead of a simple owner column.
- No-dedup keeps writes simple and ownership clean now, at the cost of some duplicate rows for repeated URLs — acceptable at current scale.

**Revisit if:**
- Storage/duplication becomes a real cost at scale.
- We want a "canonical link per destination" concept.
- We want to explore the hashing/indexing exercise for its own sake (learning value).

## Salted/XOR'd counter for short code generation (deferred 2026-07-06)

**Decision made:** Short codes are generated from a global auto-incrementing counter (DB auto-increment — see also [[redis-incr-counter-with-aof]] for the deferred Redis alternative), base62-encoded directly — no salting.

**The alternative (salted/XOR'd counter):** Same global counter approach, but before base62-encoding, XOR the integer ID with a fixed random salt (or otherwise scramble it reversibly). This is what some real-world systems (e.g. Bitly) reportedly do. The code still maps 1:1 to a counter value internally, so you keep the "guaranteed no collision" property of a counter-based approach, but externally the codes no longer look sequential — so they can't be trivially enumerated (stubby.io/1, /2, /3...) to discover every link in the system or to infer total link volume/growth rate over time.

**Why deferred:**
- Adds a bit of complexity (choosing/storing the salt, reversible scrambling logic) for a concern — enumeration/information leak — that's a real but non-blocking issue for v1.
- Plain counter + base62 is simpler to reason about and implement first; the salting step can be layered on top later without changing the underlying counter/collision-free mechanism.

**Revisit if:**
- Enumerability of short codes becomes an actual concern (e.g. scraping, privacy, competitors estimating volume).
- We want the non-guessability of random codes without giving up the collision-free guarantee of a counter.

## Redis INCR counter with AOF persistence, instead of DB auto-increment (deferred 2026-07-06) {#redis-incr-counter-with-aof}

**Decision made:** Use the DB's native auto-increment (sequence) for the ID counter used in short code generation, not Redis.

**The alternative (Redis `INCR`):** Since Redis is already in the design as a read cache (cache-aside, see redirect-path discussion), reuse it for ID generation too via atomic `INCR`. Both Redis `INCR` and a DB sequence are O(1) — this isn't a raw-speed decision. The real trade-off is durability: a DB sequence is durable by construction (part of the DB, survives restarts, included in backups). Redis's counter only survives a restart if persistence is explicitly configured via AOF (Append Only File — logs every write as it happens, replayed on startup to rebuild state). Without AOF, a Redis restart (crash, redeploy, memory-pressure eviction, or just a local dev machine restarting) resets the counter to 0, causing the next `INCR` calls to hand out already-used IDs — an actual short-code collision, not just a harmless gap.

If we do adopt Redis `INCR` for this later, AOF should be configured with `appendfsync everysec` (bounds data loss to ~1 second, much better than RDB snapshot intervals, and cheap enough given this is a single small counter with low write volume). Also needs a persistence volume/mount if run in a container, and a restart policy, or persistence is moot.

**Why deferred:**
- Avoids taking on Redis as a hard dependency for the *write* path (link creation) on top of already using it for reads. Losing Redis today only degrades read performance (falls back to DB); tying ID generation to Redis would mean losing Redis blocks *all* link creation too.
- DB auto-increment requires no persistence configuration at all — durability is inherited for free from the DB we already depend on.
- No local Redis setup exists yet in the project (no gem, no Procfile entry, no Docker config) — starting with DB auto-increment avoids introducing Redis before it's needed for anything beyond this.

**Revisit if:**
- DB sequence contention or latency becomes an actual bottleneck at higher write volume (unlikely at our current ~1000 rps read-peak / 1000:1 read:write ratio, since writes are a small fraction of that).
- Redis is already a hard dependency for other reasons by that point, making the added write-path coupling less of a net-new risk.
