---
name: supabase-migrate
description: Create and apply Supabase DB migrations for the MotoGo project (msmototaxi) using the Supabase CLI — new migration files, supabase db push, checking sync status. Use when asked to change the DB schema, add/alter a table, write a migration, apply migrations, or check whether local migrations match the remote Supabase project.
---

All paths below are relative to `msmototaxi/` (this project's root — the
directory containing `pubspec.yaml` and `supabase/`).

すべてのパスは `msmototaxi/`（`pubspec.yaml` と `supabase/` がある
このプロジェクトのルート）からの相対パス。

This project's Supabase project is `msmototaxi-sp` (ref `abjwfyzwveaeyaetpumb`,
region `sa-east-1` / São Paulo), already linked in `supabase/config.toml` and
`supabase/.temp/project-ref`. Migrations live in `supabase/migrations/` and
are applied with the Supabase CLI — there's no separate ORM or migration
runner.

## Prerequisites

- **Supabase CLI must be installed and logged in.** Verified working here via:
  ```bash
  npm install -g supabase   # if `supabase --version` fails
  ```
- **The CLI login session does NOT persist across shells in this
  environment** — a `supabase db push` in a fresh shell will fail with
  `LegacyPlatformAuthRequiredError` even after a successful `supabase login`
  earlier in the same conversation/session. Always re-login first:
  ```bash
  supabase login --token <personal-access-token> --name "msmototaxi-dev"
  ```
  Get a token from https://supabase.com/dashboard/account/tokens (ask the
  user for one if you don't have it — it's a credential, treat it like a
  password, never commit it or put it in a file tracked by git).

## Check current sync status (safe, read-only)

```bash
cd msmototaxi
supabase migration list      # shows local vs remote migration timestamps side by side
supabase db push --dry-run   # prints what WOULD be applied, without touching the DB
```
Both verified working in this environment; `db push --dry-run` printed
`"Remote database is up to date."` when local and remote already matched.

## Create a new migration

```bash
cd msmototaxi
supabase migration new <short_description>
# -> creates supabase/migrations/<timestamp>_<short_description>.sql
```
Then write the SQL by hand in that file. Follow the style of the existing
`supabase/migrations/20260901155514_init_schema.sql`:
- Bilingual comments (English + Japanese) on every table/policy, matching
  the rest of this codebase's convention.
- Enable RLS on every new table and add explicit policies — don't leave a
  table with RLS off.
- If the table needs live updates on the client, add it to the realtime
  publication: `alter publication supabase_realtime add table public.<table>;`

## Apply migrations

```bash
cd msmototaxi
supabase login --token <token> --name "msmototaxi-dev"   # see Prerequisites — needed every fresh shell
supabase db push
```
This applies any local migrations not yet recorded on the remote. It is
**not** a dry run — it changes the live database. Prefer running
`supabase db push --dry-run` first to see what will happen, especially once
the project has real user data (currently it doesn't — see project status).

After pushing, confirm with `supabase migration list` that `local` and
`remote` timestamps now match.

## Verifying a migration actually worked (beyond the CLI's own success message)

The CLI's success message only means the SQL executed without error — it
doesn't confirm the resulting schema does what you intended. Spot-check via
the REST API using the project's anon/publishable key (from `.env`):
```bash
curl -s "https://abjwfyzwveaeyaetpumb.supabase.co/rest/v1/<table>?select=*&limit=1" \
  -H "apikey: <SUPABASE_ANON_KEY from .env>"
```
An empty `[]` with HTTP 200 means the table exists and RLS allowed the
anon-key read (or denied it gracefully) — an error body means something's
wrong (typo'd table/column name, RLS misconfigured, etc.).

## Gotchas

- **Login doesn't persist between shells.** See Prerequisites — this bit
  every push in testing here. Don't assume a `supabase login` from earlier
  in the conversation is still active; re-login defensively before any
  write operation (`db push`).
- **`--size` on `supabase projects create` fails on free-plan orgs** with
  `"Instance size cannot be specified for free plan organizations."` — not
  directly migration-related, but relevant if this skill is ever extended
  to spin up a fresh project; omit `--size` entirely.
- **Supabase project region is immutable.** If a schema change is
  fundamental enough that you're tempted to recreate the project (e.g. to
  fix a region mistake), that's a `supabase projects create` + full
  migration replay, not a migration itself. This project is already in
  `sa-east-1` (São Paulo) — don't recreate it without the user's explicit
  sign-off first.
- **`.env`'s `SUPABASE_ANON_KEY`** in this project is the newer
  `sb_publishable_...`-style key, passed to `supabase_flutter` as
  `publishableKey:` (not the deprecated `anonKey:` param) — see
  `lib/core/supabase/supabase_config.dart`. Doesn't affect migrations
  directly, but matters if a migration verification curl uses the wrong
  key style.
