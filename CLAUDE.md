# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

このファイルは、このリポジトリで作業する際にClaude Code（claude.ai/code）に
与えるガイダンス。

## What this is / これは何か

MotoGo: a moto-taxi ride-hailing app for Registro, São Paulo (Brazil).
Passenger and driver apps share a single Flutter codebase, built as
separate flavors. Backend is Supabase (Postgres + PostGIS + Auth +
Realtime), region `sa-east-1` (São Paulo). Product/business background
(target area, pricing model, competitive landscape) lives in
`../slides/slides.md`, a sibling directory that is **not** part of this
git repo — read it when you need the "why."

This repo is developed on Windows without an Android/iOS emulator or a
Mac; see the notes below before assuming a mobile build path works here.

MotoGo: ブラジル・サンパウロ州Registro市向けのモトタクシー配車アプリ。
乗客用・ドライバー用アプリは1つのFlutterコードベースを共有し、別flavorとして
ビルドする。バックエンドはSupabase（Postgres + PostGIS + Auth + Realtime）、
リージョンは `sa-east-1`（São Paulo）。プロダクト・事業面の背景
（対象エリア、料金モデル、競合状況）は `../slides/slides.md`
（このgitリポジトリには含まれない別ディレクトリ）にある —
「なぜこうなっているか」を知りたい時はそちらを参照。

このリポジトリはAndroid/iOSエミュレータもMacも無いWindows環境で開発されて
いる。モバイルビルドの手順がこの環境でそのまま動くと想定する前に、
下記の注意事項を確認すること。

## Commands / コマンド

Flutter is at `/c/flutter/bin` but not on PATH in most non-interactive
shells — prefix commands with `export PATH="$PATH:/c/flutter/bin"`.

Flutterは `/c/flutter/bin` にあるが、多くの非対話シェルではPATHに
入っていない — コマンドの前に `export PATH="$PATH:/c/flutter/bin"` を
付けること。

```bash
flutter analyze                                              # static analysis / 静的解析
flutter test                                                 # runs test/widget_test.dart / test/widget_test.dartを実行
flutter test --plain-name "Shows the login screen"           # a single test by name / 名前指定で単一テストを実行

flutter pub get                                               # also regenerates lib/l10n/generated/ (AppLocalizations) from lib/l10n/*.arb / lib/l10n/*.arbからlib/l10n/generated/（AppLocalizations）も再生成する
bash tool/gen_web_index.sh                                   # regenerate web/index.html with the Google Maps key from .env — required before any web build/run
                                                               # .envのGoogle Mapsキーでweb/index.htmlを再生成 — Web版のビルド/実行前に必須
flutter run -d chrome -t lib/main_passenger.dart              # run passenger flavor in Chrome (no emulator needed) / Chromeで乗客用flavorを実行（エミュレータ不要）
flutter run -d chrome -t lib/main_driver.dart                 # run driver flavor in Chrome / Chromeでドライバー用flavorを実行
flutter build web -t lib/main_passenger.dart                  # web build -> build/web/ / Web版ビルド → build/web/

flutter run --flavor passenger -t lib/main_passenger.dart     # Android (needs a device/emulator this environment lacks) / Android（この環境に無い実機/エミュレータが必要）
flutter run -d windows                                        # Windows desktop (needs Developer Mode enabled — see Gotchas) / Windowsデスクトップ（開発者モードが必要 — 落とし穴の項参照）

supabase login --token <token> --name "msmototaxi-dev"        # required every fresh shell — see Gotchas / 新しいシェルのたびに必要 — 落とし穴の項参照
supabase migration new <description>                          # new file under supabase/migrations/ / supabase/migrations/に新規ファイル作成
supabase db push                                               # apply local migrations to the linked project / ローカルのマイグレーションをリンク済みプロジェクトに適用
supabase migration list                                        # compare local vs remote / ローカルとリモートを比較
```

Three project skills wrap these with more detail and environment-specific
gotchas, verified working in this environment: `run-msmototaxi` (build +
headless Playwright driving/screenshots — see there for why pixel-coordinate
clicks are used instead of selectors on Flutter web), `flutter-check`
(analyze + test), `supabase-migrate` (migrations). `project-conventions`
documents the directory layout and the bilingual-comment style below.

これらをより詳しく・この環境特有の落とし穴込みでラップした3つのプロジェクト
スキルがあり、いずれもこの環境で動作確認済み: `run-msmototaxi`
（ビルド＋Playwrightによるヘッドレス操作/スクリーンショット —
Flutter Webでセレクタではなくピクセル座標クリックを使う理由もそちらに記載）、
`flutter-check`（analyze + test）、`supabase-migrate`（マイグレーション）。
`project-conventions` はディレクトリ構成と、下記の英日併記スタイルを
まとめている。

## Architecture / アーキテクチャ

**Flavor split.** `lib/flavors.dart` defines `Flavor.passenger` /
`Flavor.driver` and an `AppConfig` singleton set once at startup.
`lib/main_passenger.dart` / `lib/main_driver.dart` are the real
entrypoints; `lib/main.dart` just aliases the passenger flavor for
convenience. Both flavors run the same `MotoGoApp` (`lib/app.dart`) and
differ only through `AppConfig.instance.flavor` — e.g. `app_router.dart`
picks `/passenger` vs `/driver` as the post-login route based on it.
Android has matching `productFlavors` (applicationId suffix + display
name) in `android/app/build.gradle.kts`; iOS flavor/scheme setup does not
exist yet (needs Xcode on a Mac — see README).

**flavor分離。** `lib/flavors.dart` が `Flavor.passenger` /
`Flavor.driver` と、起動時に一度だけ設定される `AppConfig` シングルトンを
定義する。`lib/main_passenger.dart` / `lib/main_driver.dart` が実際の
エントリポイントで、`lib/main.dart` は開発の便宜上、乗客用flavorの
エイリアスになっているだけ。両flavorとも同じ `MotoGoApp`
（`lib/app.dart`）を実行し、`AppConfig.instance.flavor` の違いだけで
挙動が分岐する — 例えば `app_router.dart` はこれを見てログイン後の
遷移先を `/passenger` か `/driver` かに決める。Androidには対応する
`productFlavors`（applicationId接尾辞・表示名の違い）が
`android/app/build.gradle.kts` に設定済み。iOSのflavor/スキーム設定は
まだ無い（MacでのXcode作業が必要 — README参照）。

**Routing is auth-state-driven, not just declarative.** `app_router.dart`
builds one `GoRouter` whose `redirect` callback reads Supabase auth state
(via `authStateProvider`/`currentUserProvider` in `core/auth/auth_state.dart`)
and bounces between `/login` and the flavor's home route. A
`GoRouterRefreshStream` bridges the Riverpod auth stream to go_router's
`Listenable`-based `refreshListenable` so redirects re-evaluate on
sign-in/out without manual navigation calls.

**ルーティングは単なる宣言的定義ではなく認証状態駆動。**
`app_router.dart` は1つの `GoRouter` を構築し、その `redirect`
コールバックがSupabaseの認証状態（`core/auth/auth_state.dart` の
`authStateProvider`/`currentUserProvider` 経由）を読んで `/login` と
flavorごとのホーム画面の間を行き来させる。`GoRouterRefreshStream` が
Riverpodの認証ストリームをgo_routerの `Listenable` ベースの
`refreshListenable` に橋渡ししているため、ログイン/ログアウト時に
手動でナビゲーションを呼ばなくてもリダイレクト判定が再評価される。

**Dev auth bypass — temporary, load-bearing.** Phone-OTP login is
implemented (`core/auth/auth_repository.dart`), but Supabase's SMS
provider isn't configured yet, so `core/auth/dev_auth_bypass.dart`
provides a `devAuthBypassProvider` that `app_router.dart`'s redirect logic
treats as equivalent to being signed in. The login screen's button
currently just flips this flag instead of doing real OTP. This means
screens past login (e.g. `PassengerHomeScreen`) run **without** a real
`auth.uid()` — anything that needs to write to a table with an
`auth.uid() = ...` RLS policy (see `rides`) will fail until real auth
replaces this bypass. Don't build features that assume a real signed-in
user without accounting for this.

**開発用ログインバイパス — 一時的だが現状の動作を支えている。**
電話番号OTPログイン自体は実装済み（`core/auth/auth_repository.dart`）だが、
SupabaseのSMSプロバイダがまだ未設定のため、`core/auth/dev_auth_bypass.dart`
が `devAuthBypassProvider` を提供し、`app_router.dart` のリダイレクト
ロジックはこれを「ログイン済み」と同等に扱う。ログイン画面のボタンは
現状、実際のOTP認証をせずこのフラグを立てるだけ。つまりログイン後の画面
（`PassengerHomeScreen`等）は**実際の`auth.uid()`を持たない状態**で
動いている — `auth.uid() = ...` というRLSポリシー（`rides`参照）を持つ
テーブルへの書き込みは、このバイパスが実認証に置き換わるまで失敗する。
これを踏まえずに「実際にログイン済みユーザーがいる」前提の機能を作らない
こと。

**Supabase config is `.env`-driven with a graceful "unconfigured" state.**
`core/supabase/supabase_config.dart` reads `SUPABASE_URL`/`SUPABASE_ANON_KEY`
from `.env` (loaded as a Flutter asset, not compiled in) and falls back to
placeholder values if unset, so the app still boots without a real backend
— `SupabaseConfig.isConfigured` lets UI show a "not connected" state
instead of crashing. The Google Maps key follows a *different* pattern
per platform because it can't go through `.env` the same way — see
README's table (Android: `android/local.properties`, iOS: inline in
`AppDelegate.swift` for now, Web: baked into a gitignored `web/index.html`
generated from `web/index.html.template` by `tool/gen_web_index.sh`,
which must be re-run whenever the key changes).

**Supabaseの設定は`.env`駆動で、「未設定」状態にも優雅に対応する。**
`core/supabase/supabase_config.dart` は `SUPABASE_URL`/`SUPABASE_ANON_KEY`
を `.env`（コンパイル時に埋め込むのではなくFlutterアセットとして読み込む）
から読み、未設定ならプレースホルダー値にフォールバックする — そのため
実バックエンドが無くてもアプリは起動でき、`SupabaseConfig.isConfigured`
を使ってUI側で「未接続」状態を表示できる（クラッシュさせない）。
Google Mapsのキーは`.env`と同じ経路を通せないため、プラットフォームごとに
*別のパターン*になっている — READMEの表を参照（Android:
`android/local.properties`、iOS: 現状 `AppDelegate.swift` に直書き、
Web: `tool/gen_web_index.sh` が `web/index.html.template` から生成する
gitignore対象の `web/index.html` に焼き込む。キーを変更したら
再実行が必要）。

**DB schema** (`supabase/migrations/20260901155514_init_schema.sql`):
`profiles` (1:1 with `auth.users`, has `role` enum) → `driver_profiles`
(1:1 with profiles where role='driver'; vehicle info, `status`,
`is_approved`) → `driver_locations` (1 row per driver, UPSERTed on each
GPS ping, `geography(point)` + GiST index for nearest-driver queries) and
`rides` (full lifecycle: `requested`→`matched`→`en_route`→`in_progress`→
`completed`/`cancelled`, plus fare/commission fields). A trigger
auto-creates `profiles` (and `driver_profiles` if `role: 'driver'` was
passed at signup) on `auth.users` insert. RLS is enabled on every table;
`driver_locations` and `rides` are registered on the `supabase_realtime`
publication for live client updates. Ride creation and PostGIS-based
matching (planned as an Edge Function) are not implemented yet — the
passenger home screen's "配車を依頼する" button is currently a stub (see
`PassengerHomeScreen._requestRide`).

**DBスキーマ**（`supabase/migrations/20260901155514_init_schema.sql`）:
`profiles`（`auth.users`と1:1、`role` enum持ち）→ `driver_profiles`
（role='driver'のprofilesと1:1。車両情報、`status`、`is_approved`）→
`driver_locations`（ドライバー1人1行、GPS更新のたびにUPSERT、
`geography(point)`＋GiSTインデックスで近傍ドライバー検索用）、
そして `rides`（`requested`→`matched`→`en_route`→`in_progress`→
`completed`/`cancelled`の全ライフサイクル＋運賃/手数料フィールド）。
`auth.users`へのinsert時にトリガーが `profiles`（サインアップ時に
`role: 'driver'` が渡されていれば `driver_profiles` も）を自動作成する。
全テーブルでRLSが有効。`driver_locations` と `rides` は
`supabase_realtime` publicationに登録済みでクライアントへのリアルタイム
配信に対応。配車依頼の作成とPostGISベースのマッチング（Edge Functionとして
計画中）はまだ未実装 — 乗客用ホーム画面の「配車を依頼する」ボタンは
現状スタブ（`PassengerHomeScreen._requestRide`参照）。

**Passenger home screen state machine**
(`features/passenger/home/passenger_home_screen.dart`): pickup defaults to
device GPS (via `geolocator`, draggable marker once set); tapping the map
sets dropoff; the request button enables only once both are set. Location
permission/service failures degrade to "tap the map to pick a point
manually" rather than blocking the screen.

**乗客用ホーム画面の状態遷移**
（`features/passenger/home/passenger_home_screen.dart`）: 乗車地点は
デフォルトで端末のGPS（`geolocator`経由、設定後はドラッグ可能な
マーカーになる）。地図をタップすると降車地点を設定。依頼ボタンは両方
設定されて初めて有効になる。位置情報の権限/サービスが使えない場合も
画面をブロックせず、「地図をタップして手動で選ぶ」形に縮退する。

**i18n: pt (default) + ja, resolved device-first with a manual override.**
UI strings live in `lib/l10n/app_pt.arb` / `app_ja.arb`, compiled to
`AppLocalizations` by `flutter gen-l10n` (auto-run via `generate: true`
in pubspec.yaml — the output under `lib/l10n/generated/` is gitignored).
`app.dart`'s `localeResolutionCallback` matches the device's language by
*language code only* (so a `pt_BR` device resolves to our `pt` ARB) and
falls back to pt if unsupported. `core/locale/locale_controller.dart`'s
`LocaleController` lets the user override this via
`LanguageSwitcherButton` (shown in every screen's AppBar); the override
is persisted through SharedPreferences and read back at startup in
`bootstrap.dart`, because SharedPreferences is only accessible
asynchronously and `LocaleController`'s initial state has to be known
synchronously when the provider is built. Adding a UI string always
means adding the key to *both* ARB files — see `bilingual-comments`
skill for why this is a distinct mechanism from the bilingual-comment
convention below, not an application of it.

**i18n: pt（デフォルト）+ ja、端末言語をまず見て手動上書きも可能。**
UI文言は `lib/l10n/app_pt.arb` / `app_ja.arb` にあり、`flutter gen-l10n`
（pubspec.yamlの`generate: true`により自動実行 — 出力先の
`lib/l10n/generated/` はgitignore対象）で `AppLocalizations` に
コンパイルされる。`app.dart` の `localeResolutionCallback` は端末の言語を
*language codeのみ*で照合する（`pt_BR`端末でも `pt` のARBに解決される）ため、
未対応言語ならptにフォールバックする。`core/locale/locale_controller.dart`
の `LocaleController` は、各画面のAppBarに表示される
`LanguageSwitcherButton` 経由でこれを手動上書きできるようにする —
上書き結果はSharedPreferencesで永続化され、`bootstrap.dart` の起動時に
読み込まれる。これはSharedPreferences自体が非同期でしかアクセスできない
一方、providerを構築する時点で `LocaleController` の初期stateは同期的に
分かっている必要があるため。UI文言を追加する際は必ず*両方の*ARBファイルに
キーを追加すること — これがなぜ下記の英日併記コメント規約の適用例ではなく
別の仕組みなのかは `bilingual-comments` スキル参照。

## Style / スタイル

Every comment (doc comments, file-level comments, non-trivial inline
comments) is written in English AND Japanese together, written at the
same time — not code identifiers, not UI strings, not commit messages.
See the `bilingual-comments` skill for the exact rule and examples; write
this way by default, in every file you touch, without being asked each
time.

すべてのコメント（docコメント、ファイル冒頭コメント、自明でない
インラインコメント）は英語と日本語を同時に併記して書く — コード識別子、
UI文言、コミットメッセージは対象外。正確なルールと例は
`bilingual-comments` スキル参照。毎回指示されなくても、触るファイルでは
デフォルトでこのスタイルで書くこと。

## Gotchas / 落とし穴

- **Windows desktop builds need Developer Mode** (`start
  ms-settings:developers` → enable) — without it, `flutter run -d windows`
  fails with `Error: Building with plugins requires symlink support.`
  Chrome (`-d chrome`) doesn't have this requirement and is the easier
  default for seeing the app run in this environment.

  **Windowsデスクトップ版のビルドには開発者モードが必要**（`start
  ms-settings:developers` で有効化）— これが無いと `flutter run -d
  windows` が `Error: Building with plugins requires symlink support.`
  で失敗する。Chrome（`-d chrome`）はこの制約が無く、この環境で動作を
  確認するにはこちらがデフォルトとして手軽。

- **Supabase CLI login does not persist across shells** here — re-run
  `supabase login --token ...` before any `supabase db push`, even if you
  logged in earlier in the same session.

  **この環境ではSupabase CLIのログインはシェルをまたいで永続化されない**
  — 同じセッション内で以前ログイン済みでも、`supabase db push` の前は
  毎回 `supabase login --token ...` をやり直すこと。

- **`python3 -m http.server` silently fails** on this machine (`python3`
  resolves to a Windows Store stub) — use the Node-based server in the
  `run-msmototaxi` skill's `driver.mjs` instead.

  **このマシンでは `python3 -m http.server` が無言で失敗する**
  （`python3` がWindows Storeのスタブを指しているため）— 代わりに
  `run-msmototaxi` スキルの `driver.mjs` にあるNode製サーバーを使うこと。
