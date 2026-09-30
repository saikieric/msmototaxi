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

このプロジェクトのSupabaseプロジェクトは `msmototaxi-sp`（ref
`abjwfyzwveaeyaetpumb`、リージョン `sa-east-1` / São Paulo）で、
`supabase/config.toml` と `supabase/.temp/project-ref` に既にリンク済み。
マイグレーションは `supabase/migrations/` に置かれ、Supabase CLIで適用する
（別途ORMやマイグレーションランナーは無い）。

## Prerequisites / 前提条件

- **Supabase CLI must be installed and logged in.** Verified working here via:
  ```bash
  npm install -g supabase   # if `supabase --version` fails
  ```
  **Supabase CLIがインストール済みでログイン済みであること。** 動作確認済みの
  導入方法（`supabase --version` が失敗する場合）:
  ```bash
  npm install -g supabase
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

  **この環境ではCLIのログインセッションはシェルをまたいで永続化されない。**
  同じ会話の中で以前 `supabase login` に成功していても、新しいシェルでの
  `supabase db push` は `LegacyPlatformAuthRequiredError` で失敗する。
  必ず先に再ログインすること:
  ```bash
  supabase login --token <personal-access-token> --name "msmototaxi-dev"
  ```
  トークンは https://supabase.com/dashboard/account/tokens で発行する
  （手元に無ければユーザーに依頼する — 認証情報なのでパスワード同様に扱い、
  絶対にコミットしたりgit管理下のファイルに書いたりしないこと）。

## Check current sync status (safe, read-only) / 同期状態の確認（安全・読み取り専用）

```bash
cd msmototaxi
supabase migration list      # shows local vs remote migration timestamps side by side
supabase db push --dry-run   # prints what WOULD be applied, without touching the DB
```
Both verified working in this environment; `db push --dry-run` printed
`"Remote database is up to date."` when local and remote already matched.

いずれもこの環境で動作確認済み。ローカルとリモートが一致している場合、
`db push --dry-run` は `"Remote database is up to date."` と出力した。

## Create a new migration / 新しいマイグレーションの作成

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

生成されたファイルにSQLを手書きする。既存の
`supabase/migrations/20260901155514_init_schema.sql` のスタイルに合わせる:
- 全テーブル・全ポリシーに英語＋日本語の併記コメントを付ける（このコードベース
  全体の慣習に合わせる）
- 新しいテーブルは必ずRLSを有効化し、明示的なポリシーを追加する
  （RLS無効のまま放置しない）
- クライアント側でリアルタイム更新が必要なテーブルは、realtime publicationに
  追加する: `alter publication supabase_realtime add table public.<table>;`

## Apply migrations / マイグレーションの適用

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

ローカルにあってリモートに未反映のマイグレーションを適用する。これは
**dry runではない** — 実際に本番DBを変更する。特に実データが入り始めた後は、
先に `supabase db push --dry-run` で内容を確認することを推奨する
（現時点ではまだ実データは無い）。

適用後は `supabase migration list` で `local` と `remote` のタイムスタンプが
一致したことを確認する。

## Verifying a migration actually worked / マイグレーションが実際に機能したかの確認

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

CLIの成功メッセージは「SQLがエラー無く実行された」ことしか意味せず、
意図通りのスキーマになったかまでは保証しない。`.env` のanon/publishable
keyを使ってREST API経由で簡易確認するとよい（上記curlコマンド参照）。
空配列 `[]` とHTTP 200が返れば、テーブルが存在しanon keyでの読み取りが
許可（または適切に拒否）されている。エラー本文が返る場合は何か問題がある
（テーブル名/カラム名の誤字、RLS設定ミスなど）。

## Gotchas / 落とし穴

- **Login doesn't persist between shells.** See Prerequisites — this bit
  every push in testing here. Don't assume a `supabase login` from earlier
  in the conversation is still active; re-login defensively before any
  write operation (`db push`).

  **ログインはシェルをまたいで永続化されない。** 前提条件の項目参照。
  この環境での検証中、毎回のpushでこれに引っかかった。会話の前の方で
  `supabase login` していても有効とは限らないので、書き込み操作
  （`db push`）の前は念のため必ず再ログインすること。

- **`--size` on `supabase projects create` fails on free-plan orgs** with
  `"Instance size cannot be specified for free plan organizations."` — not
  directly migration-related, but relevant if this skill is ever extended
  to spin up a fresh project; omit `--size` entirely.

  **無料プランの組織では `supabase projects create` の `--size` 指定が
  失敗する**（`"Instance size cannot be specified for free plan
  organizations."`）。マイグレーションと直接関係は無いが、このスキルを
  新規プロジェクト作成にまで拡張する場合は関係するので、`--size` は
  完全に省略すること。

- **Supabase project region is immutable.** If a schema change is
  fundamental enough that you're tempted to recreate the project (e.g. to
  fix a region mistake), that's a `supabase projects create` + full
  migration replay, not a migration itself. This project is already in
  `sa-east-1` (São Paulo) — don't recreate it without the user's explicit
  sign-off first.

  **Supabaseプロジェクトのリージョンは作成後に変更できない。**
  リージョンを直すためにプロジェクトを作り直したくなるほどの根本的な
  変更が必要な場合、それはマイグレーションではなく
  `supabase projects create` ＋ 全マイグレーションの再適用になる。
  このプロジェクトは既に `sa-east-1`（São Paulo）にあるので、
  ユーザーの明示的な同意無しに作り直さないこと。

- **`.env`'s `SUPABASE_ANON_KEY`** in this project is the newer
  `sb_publishable_...`-style key, passed to `supabase_flutter` as
  `publishableKey:` (not the deprecated `anonKey:` param) — see
  `lib/core/supabase/supabase_config.dart`. Doesn't affect migrations
  directly, but matters if a migration verification curl uses the wrong
  key style.

  **`.env` の `SUPABASE_ANON_KEY`** は、このプロジェクトでは新方式の
  `sb_publishable_...` 形式のキーで、`supabase_flutter` へは
  （非推奨の `anonKey:` ではなく）`publishableKey:` として渡している
  （`lib/core/supabase/supabase_config.dart` 参照）。マイグレーション自体には
  直接影響しないが、マイグレーション確認用のcurlで誤った形式のキーを
  使わないよう注意。

- **Free-plan projects auto-pause after about a week of no API activity**
  — confirmed here: after roughly three weeks without any request to this
  project, `curl .../auth/v1/health` failed with `Could not resolve host`
  (DNS-level, not just a slow response), and `supabase projects list`
  showed `"status":"INACTIVE"`. There is **no CLI command to restore a
  paused project** (`supabase projects restore`/`resume`/`unpause` don't
  exist) — it must be done from the Dashboard: open
  `https://supabase.com/dashboard/project/abjwfyzwveaeyaetpumb` and click
  "Restore project". After clicking restore, the status goes
  `INACTIVE` → `COMING_UP` → `ACTIVE_HEALTHY`; DNS starts resolving during
  `COMING_UP` but the origin isn't up yet (a health-check curl returns
  Cloudflare's `521 Web server is down` in between) — this whole sequence
  took a little over 4 minutes end-to-end here. Poll `supabase projects
  list` for `ACTIVE_HEALTHY` and the health-check curl for HTTP 200
  before assuming it's still broken. If a project has gone unused for
  roughly a week, check its status before spending time debugging
  something else — the passenger/driver apps' current dev-auth-bypass
  flow (see `CLAUDE.md`) never actually calls Supabase, so a paused
  project won't show up as a blank screen or any obvious in-app error;
  it just silently means any *real* Supabase call will fail.

  **無料プランのプロジェクトは、API呼び出しが約1週間無いと自動的に
  一時停止する** — この環境で確認済み: このプロジェクトへのリクエストが
  約3週間無かった後、`curl .../auth/v1/health` が「ホスト名を解決できない」
  （応答が遅いのではなく、DNSレベルで失敗）で失敗し、
  `supabase projects list` は `"status":"INACTIVE"` を示した。
  **一時停止したプロジェクトを復旧するCLIコマンドは存在しない**
  （`supabase projects restore`/`resume`/`unpause`はどれも無い）—
  Dashboardから行う必要がある:
  `https://supabase.com/dashboard/project/abjwfyzwveaeyaetpumb` を開き
  「Restore project」をクリックする。クリック後、ステータスは
  `INACTIVE` → `COMING_UP` → `ACTIVE_HEALTHY` と遷移する。`COMING_UP`の間に
  DNSは解決され始めるが、オリジンサーバー自体はまだ起動していない
  （その間のヘルスチェックcurlはCloudflareの`521 Web server is down`を
  返す）— この環境では一連の流れに合計4分強かかった。`supabase
  projects list`で`ACTIVE_HEALTHY`になり、ヘルスチェックcurlがHTTP 200を
  返すまでポーリングしてから、まだ壊れていると判断すること。約1週間
  操作されていないプロジェクトがあれば、他の問題を疑って時間をかける前に
  まずステータスを確認すること — 乗客/ドライバーアプリの現状の開発用
  認証バイパスフロー（`CLAUDE.md`参照）は実際にはSupabaseを一切呼ばない
  ため、プロジェクトが一時停止していてもアプリ内で白い画面や明白な
  エラーとしては現れない — 単に、*実際の*Supabase呼び出しが静かに
  失敗するだけになる。
