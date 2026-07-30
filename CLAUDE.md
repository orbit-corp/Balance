# stubby

## Working rule (non-negotiable)

Do not implement any new feature, endpoint, schema change, or architectural component until it has been brainstormed and discussed with Victor first. This applies at the start of every session, including new ones — check this file before writing code.

Brainstorming means, at minimum:
1. Discuss the problem/requirement and why it matters.
2. Walk through 2+ viable approaches and their trade-offs (performance, complexity, scalability, cost).
3. Get explicit agreement on the approach before writing any code.

If Victor asks for something to be implemented directly without this discussion having happened, pause and start the brainstorming conversation instead of coding. Small fixes (typos, formatting, non-behavioral cleanup) are exempt — use judgment, but default to asking if unsure.

## Migrations

**This project is pre-launch. There is no production database and no other developer's database to protect.** Treat the schema as freely editable.

So, when a table needs to change:

- **Roll back and edit the existing migration.** `bin/rails db:rollback` (or `db:rollback STEP=n`), change the `create_table` or `add_column` in place, then `bin/rails db:migrate`. The migration history should read as if the schema had always been this way.
- **Do not stack a new migration to patch a recent one.** No `add_column`/`remove_column`/`change_column` migration whose only purpose is to fix something an existing migration in this repo got wrong. That noise is the price of protecting production data, and there is no production data.
- **Never mutate records from a migration.** No `Model.find_each { … }`, no `execute "UPDATE …"`, no backfill blocks. If existing dev rows are in the way, roll back, fix the schema, and reseed or recreate the data (`bin/rails db:reset`, a seed file, or `bin/rails runner`). Data fixes are a separate, explicit step — not a side effect of a schema change.
- **`bin/rails db:reset` / `db:drop db:create db:migrate` are fine** when a rollback would be more trouble than a rebuild. Ask first only if there is dev data worth keeping.

This convention ends the moment the app is deployed or a second developer has a local database — at that point, forward-only migrations become mandatory. Flag it rather than assume.
