---
name: project-conventions
description: Directory layout and coding/doc style conventions for the MotoGo project (msmototaxi) — where new code/files go, the bilingual (English+Japanese) comment convention, naming patterns, and how the .claude/skills/ directory itself is organized. Use when asked where to put a new file/feature, what style to follow, how this project is organized, or when creating a new SKILL.md for this project.
---

Reference only — no commands to run. For actual build/test/migration
commands, see [run-msmototaxi](../run-msmototaxi/SKILL.md),
[flutter-check](../flutter-check/SKILL.md), and
[supabase-migrate](../supabase-migrate/SKILL.md).

参照専用 — 実行コマンドは無い。ビルド/テスト/マイグレーションの実際の
コマンドは [run-msmototaxi](../run-msmototaxi/SKILL.md)、
[flutter-check](../flutter-check/SKILL.md)、
[supabase-migrate](../supabase-migrate/SKILL.md) を参照。

## Repo layout / リポジトリ構成

```
C:\msmototaxi\              <- not a git repo itself; just a folder holding both of the below
  msmototaxi\                 <- THE git repo. Flutter app + Supabase backend. (this skill lives here)
  slides\                     <- separate, NOT a git repo. Marp slide deck (slides.md) — product/business background.
```

`msmototaxi/` is the only git repository. `slides/slides.md` is the
source of truth for product intent (target area, architecture, tech
stack, pricing model) — when in doubt about *why* something is built a
certain way, check there first.

`C:\msmototaxi` 自体はgitリポジトリではなく、単に以下2つを内包するフォルダ。
`msmototaxi/` が唯一のgitリポジトリ（Flutterアプリ＋Supabaseバックエンド、
このスキルもここにある）。`slides/` は別扱いでgit管理外 — Marpスライド
（`slides.md`）で、対象エリア・アーキテクチャ・技術スタック・料金モデル等
プロダクトの意図の一次情報。「なぜこう作っているのか」に迷ったらまず
そこを見る。

## `msmototaxi/` app layout / アプリ内の構成

```
lib/
  flavors.dart                <- Flavor enum (passenger/driver) + AppConfig singleton
  app.dart                    <- MaterialApp.router + theme, shared by both flavors
  bootstrap.dart               <- shared startup: Supabase.initialize -> runApp
  main.dart                    <- dev convenience alias for the passenger flavor
  main_passenger.dart          <- real passenger flavor entrypoint
  main_driver.dart             <- real driver flavor entrypoint
  core/                        <- cross-cutting, not screen-specific
    auth/                       <- AuthRepository, auth state providers, dev bypass flag
    router/                     <- go_router config, auth-aware redirects
    supabase/                   <- SupabaseConfig (reads .env, initializes the client)
  features/                    <- one subdir per screen/flow, grouped by who uses it
    auth/                       <- shared login screen
    passenger/home/             <- passenger-only screens
    driver/home/                 <- driver-only screens

supabase/
  config.toml                  <- CLI config, linked to the msmototaxi-sp project
  migrations/                   <- hand-written SQL, one file per `supabase migration new`

tool/
  gen_web_index.sh             <- generates web/index.html (Google Maps key) from .env

test/
  widget_test.dart             <- smoke test; see flutter-check skill for why it mocks Supabase

.claude/skills/                <- this skill + run-msmototaxi, flutter-check, supabase-migrate
```

**Adding a new screen:** put it under `features/<passenger|driver|auth>/<flow-name>/`,
following the existing `features/passenger/home/passenger_home_screen.dart`
pattern — one screen (or tightly related set of widgets) per file, named
`<thing>_screen.dart`. Shared cross-flavor logic (auth, networking, routing)
goes in `core/`, not `features/`.

**新しい画面の追加:** `features/<passenger|driver|auth>/<flow名>/` の下に置く。
既存の `features/passenger/home/passenger_home_screen.dart` の形に合わせ、
1ファイル1画面（または密接に関連するウィジェット群）、ファイル名は
`<何か>_screen.dart`。flavor共通のロジック（認証・通信・ルーティング）は
`features/` ではなく `core/` に置く。

## Style: bilingual comments (English + Japanese) / スタイル: 英語＋日本語併記コメント

Every doc comment (`///`), file-level comment, and non-trivial inline
comment (`//`) in this codebase is written **twice**: an English
paragraph/sentence, immediately followed by its Japanese translation.
This applies to Dart doc comments, SQL migration comments, shell script
headers, and `SKILL.md` prose alike. See any file under `lib/` — e.g.
`lib/flavors.dart` or `lib/core/auth/dev_auth_bypass.dart` — for the
established shape:

```dart
/// English sentence explaining what this is.
/// 日本語訳。
///
/// A second English paragraph with more detail.
/// より詳しい説明の日本語訳。
```

- Code identifiers themselves (class/function/variable names, enum
  values) stay English-only — bilingual applies to *prose*, not to code.
- User-facing UI strings are Japanese-only (this is a Japanese-market app
  for Registro, Brazil — see slides.md) — they are not bilingual pairs.
- Commit messages are English-only (see `git log`).
- This convention was adopted partway through the project (see the
  bilingual-SKILL.md commit) — if you find an older English-only comment,
  it's a gap to fill when you're already touching that code, not
  something to hunt down separately.

このコードベースのすべてのドキュメントコメント（`///`）、ファイル冒頭
コメント、自明でないインラインコメント（`//`）は**2回書く**:
英語の段落/文の直後に、その日本語訳を続ける。これはDartのdocコメント、
SQLマイグレーションのコメント、シェルスクリプトのヘッダー、`SKILL.md`の
本文すべてに当てはまる。定着した形は `lib/` 配下の任意のファイル
（例: `lib/flavors.dart`、`lib/core/auth/dev_auth_bypass.dart`）を参照。

- コード識別子自体（クラス名・関数名・変数名・enum値）は英語のみ —
  併記の対象は「文章」であって「コード」ではない。
- ユーザー向けUI文言は日本語のみ（ブラジル・Registro向けの日本語市場
  アプリ — slides.md参照）— これらは英日ペアにしない。
- コミットメッセージは英語のみ（`git log` 参照）。
- この規約はプロジェクト途中から採用した（bilingual-SKILL.mdのコミット
  参照）— 古い英語のみのコメントを見つけても、それは別途探して直す
  対象ではなく、たまたまそのコードを触った時に直せばよい程度のもの。

## Style: SQL migrations / スタイル: SQLマイグレーション

See [supabase-migrate](../supabase-migrate/SKILL.md) for the full
workflow. Style-wise: bilingual comments as above, RLS enabled + explicit
policies on every new table, and realtime-publication registration for
any table the client needs live updates from. Follow
`supabase/migrations/20260901155514_init_schema.sql` as the reference
example.

完全なワークフローは [supabase-migrate](../supabase-migrate/SKILL.md)
を参照。スタイル面では上記の英日併記コメント、新規テーブルは全てRLS
有効化＋明示的ポリシー、クライアントがリアルタイム更新を必要とする
テーブルはrealtime publicationへの登録が必要。リファレンス例として
`supabase/migrations/20260901155514_init_schema.sql` に倣うこと。

## How `.claude/skills/` itself is organized / `.claude/skills/` 自体の構成

```
.claude/skills/
  project-conventions/SKILL.md   <- this file: layout + style reference (no commands)
  run-msmototaxi/                <- build/serve/drive+screenshot the app (has a driver.mjs + its own node_modules)
  flutter-check/SKILL.md         <- flutter analyze + flutter test
  supabase-migrate/SKILL.md      <- create/apply DB migrations
```

- One skill directory per distinct task, named `<verb>-<subject>` or
  `<subject>-<verb>` (`run-msmototaxi`, `supabase-migrate`,
  `flutter-check`) — lowercase, dashes, no slashes. The directory name
  and the frontmatter `name:` must match.
- A skill that needs its own tooling (like `run-msmototaxi`'s Playwright
  driver) keeps that tooling — scripts, `package.json`, generated
  artifacts — inside its own skill directory, with a `.gitignore` for
  anything generated (`node_modules/`), not mixed into the app's own
  `lib/`/`test/`.
- Every `SKILL.md` in this project is bilingual per the convention above
  — frontmatter (`name:`, `description:`) stays English-only since
  that's metadata read by tooling, not prose.
- Every command shown in a `SKILL.md` here was actually run and verified
  in this environment before being written down — see each skill's
  Gotchas section for the environment-specific traps that were found
  that way (PATH, CLI login not persisting, `python3` being a stub,
  etc.). When adding a new skill, keep that bar: verify, don't guess.

- タスクごとに1つのスキルディレクトリ、命名は `<動詞>-<対象>` または
  `<対象>-<動詞>`（`run-msmototaxi`、`supabase-migrate`、
  `flutter-check`）— 小文字・ダッシュ区切り・スラッシュ無し。
  ディレクトリ名とfrontmatterの `name:` は一致させる。
- 専用ツールが必要なスキル（`run-msmototaxi` のPlaywrightドライバー等）は、
  そのツール一式（スクリプト・`package.json`・生成物）を自分の
  スキルディレクトリ内に持ち、生成物は`.gitignore`で除外する
  （`node_modules/` 等）。アプリ本体の `lib/`/`test/` とは混ぜない。
- このプロジェクトの `SKILL.md` は全て上記の規約に沿って英日併記 —
  frontmatter（`name:`、`description:`）はツールが読むメタデータなので
  英語のみのまま。
- ここにある `SKILL.md` に書かれたコマンドは、書く前に実際にこの環境で
  実行・検証済み — 各スキルのGotchasセクションに、その過程で見つかった
  この環境特有の落とし穴（PATH、CLIログインが永続化しない、`python3`が
  スタブである等）がまとまっている。新しいスキルを追加する際もこの基準
  （推測ではなく検証）を保つこと。
