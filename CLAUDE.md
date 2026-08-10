# stubby


## Migrations

**This project is pre-launch. There is no production database and no other developer's database to protect.** Treat the schema as freely editable.

So, when a table needs to change:

- **Roll back and edit the existing migration.** `bin/rails db:rollback` (or `db:rollback STEP=n`), change the `create_table` or `add_column` in place, then `bin/rails db:migrate`. The migration history should read as if the schema had always been this way.
- **Do not stack a new migration to patch a recent one.** No `add_column`/`remove_column`/`change_column` migration whose only purpose is to fix something an existing migration in this repo got wrong. That noise is the price of protecting production data, and there is no production data.
- **Never mutate records from a migration.** No `Model.find_each { … }`, no `execute "UPDATE …"`, no backfill blocks. If existing dev rows are in the way, roll back, fix the schema, and reseed or recreate the data (`bin/rails db:reset`, a seed file, or `bin/rails runner`). Data fixes are a separate, explicit step — not a side effect of a schema change.
- **`bin/rails db:reset` / `db:drop db:create db:migrate` are fine** when a rollback would be more trouble than a rebuild. Ask first only if there is dev data worth keeping.

This convention ends the moment the app is deployed or a second developer has a local database — at that point, forward-only migrations become mandatory. Flag it rather than assume.
