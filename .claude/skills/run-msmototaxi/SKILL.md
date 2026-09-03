---
name: run-msmototaxi
description: Build, run, and drive/screenshot the MotoGo Flutter app (msmototaxi) — passenger and driver flavors. Use when asked to run the app, launch MotoGo, screenshot a screen, verify a UI change actually renders, or check flutter analyze/flutter test pass. Covers both Android/iOS/Windows launch and headless web driving via Playwright.
---

All paths below are relative to `msmototaxi/` (this project's root — the
directory containing `pubspec.yaml`). This skill's own files live at
`.claude/skills/run-msmototaxi/`.

すべてのパスは `msmototaxi/`（このプロジェクトのルート、`pubspec.yaml` がある
ディレクトリ）からの相対パス。このスキル自体のファイルは
`.claude/skills/run-msmototaxi/` にある。

MotoGo is a Flutter app (passenger/driver flavors sharing one codebase —
see `lib/flavors.dart`) backed by Supabase, with a Google Maps view on the
passenger home screen. **There is no Android/iOS emulator or physical
device available in this environment** — the way to actually launch and
interact with the app here is the **web build**, driven headlessly with
Playwright via `.claude/skills/run-msmototaxi/driver.mjs`. That is the
primary agent path below. Windows-desktop and mobile builds are documented
as the human path since they need a display / SDK this environment lacks.

MotoGoはFlutterアプリ（乗客用・ドライバー用flavorが1コードベースを共有 —
`lib/flavors.dart` 参照）で、Supabaseをバックエンドとし、乗客用ホーム画面に
Google Mapsを表示する。**この環境にはAndroid/iOSエミュレータや実機が無い** —
実際に起動・操作できるのは**Web版ビルド**で、Playwright経由
（`.claude/skills/run-msmototaxi/driver.mjs`）でヘッドレスに操作する。
これが以下の主要な（エージェント向け）手順。Windowsデスクトップ版・
モバイル版はディスプレイ/SDKがこの環境に無いため、人間向けの手順として
参考記載のみ。

## Prerequisites (verified in this environment) / 前提条件（この環境で検証済み）

- Flutter is installed at `/c/flutter/bin` but **not on PATH** in the Bash
  tool's shell — prefix every `flutter`/`dart` command with:
  ```bash
  export PATH="$PATH:/c/flutter/bin"
  ```
  Flutterは `/c/flutter/bin` にインストールされているが、Bashツールの
  シェルでは**PATHに入っていない** — `flutter`/`dart` コマンドの前に
  毎回付ける:
  ```bash
  export PATH="$PATH:/c/flutter/bin"
  ```

- `.env` must exist with real Supabase + Google Maps values (copy
  `.env.example` and fill in) — see the project's own README for how to
  get them. Without it the app still boots (Supabase falls back to a
  "not configured" banner) but the map won't load.

  `.env` に実際のSupabase・Google Mapsの値が設定されている必要がある
  （`.env.example` をコピーして記入 — 取得方法はプロジェクトのREADME参照）。
  無くてもアプリ自体は起動する（Supabaseは「未接続」バナーにフォールバック
  する）が、地図は表示されない。

- Node.js + npm (used for the Playwright driver, not the Flutter app
  itself).

  Node.js + npm（Flutterアプリ自体ではなく、Playwrightドライバーのために
  使う）。

## Build (web, passenger flavor) / ビルド（Web版、乗客用flavor）

```bash
export PATH="$PATH:/c/flutter/bin"
flutter pub get                     # also regenerates lib/l10n/generated/ (AppLocalizations) if lib/l10n/*.arb changed
bash tool/gen_web_index.sh          # writes web/index.html with the Google Maps key from .env
flutter build web -t lib/main_passenger.dart
```
Swap `lib/main_passenger.dart` for `lib/main_driver.dart` to build the
driver flavor instead — same build command otherwise.

This produces static output in `build/web/`. It takes about a minute.

`lib/main_passenger.dart` を `lib/main_driver.dart` に置き換えれば
ドライバー用flavorをビルドできる — それ以外のコマンドは同じ。

`build/web/` に静的ファイルが生成される。所要時間は約1分。

## Run (agent path): serve + drive headlessly with Playwright / 実行（エージェント向け）: 配信してPlaywrightでヘッドレス操作

The driver's own dependencies are separate from the Flutter app's — install
once:
```bash
cd .claude/skills/run-msmototaxi
npm install   # installs playwright into this skill dir's own node_modules
npx playwright install chromium   # one-time browser download, if not already present
```

ドライバー自体の依存関係はFlutterアプリとは別 — 最初に一度だけインストール:
```bash
cd .claude/skills/run-msmototaxi
npm install
npx playwright install chromium
```

Then, from `.claude/skills/run-msmototaxi/`:
以降は `.claude/skills/run-msmototaxi/` から:

```bash
# 1. Serve the build/web output (blocks — run in background)
node driver.mjs serve 8765 &

# 2. Screenshot whatever's currently on screen after the app boots
node driver.mjs screenshot "http://localhost:8765" "screenshots/login.png"

# 3. Click a point (pixel coords, 480x900 viewport) and screenshot the result
# Coordinates below are for the login screen's dev-bypass button in ja
# (device-default locale on this machine) — see Gotchas: this shifts with
# locale/text length, so re-screenshot and re-measure if it misses.
node driver.mjs click "http://localhost:8765" 240 607 "screenshots/passenger-home.png"
```

Screenshots land wherever you point the output path (relative to the
current shell's cwd). `screenshots/` in this skill dir is a reasonable
default and is gitignored-safe to write into repeatedly.

スクリーンショットは指定した出力パス（現在のシェルのcwdからの相対パス）に
保存される。このスキルディレクトリ内の `screenshots/` がデフォルトとして
妥当で、何度書き込んでもgit管理上問題ない。

**Why pixel-coordinate clicks and not selectors:** Flutter's web build
renders the entire UI into a single `<canvas>` (CanvasKit renderer) — there
is no DOM tree of buttons/inputs to query by text or role. `driver.mjs`
clicks by `(x, y)` against a fixed 480×900 viewport. If you change the UI
layout, take a fresh `screenshot`, visually locate the new element's
position, and update the coordinates you pass to `click`.

**なぜセレクタではなくピクセル座標クリックなのか:** Flutter Web版はUI全体を
1枚の `<canvas>`（CanvasKitレンダラー）に描画するため、テキストやroleで
問い合わせできるDOMツリー（ボタン・入力欄）が無い。`driver.mjs` は固定の
480×900ビューポートに対する `(x, y)` 座標でクリックする。UIレイアウトを
変更した場合は、まず `screenshot` を撮って新しい要素の位置を目視で確認し、
`click` に渡す座標を更新すること。

Stop the server when done:
サーバーを止める:
```bash
# find and kill the node process bound to the port you used
for pid in $(netstat -ano | grep "LISTENING" | grep ":8765" | awk '{print $5}' | sort -u); do
  taskkill //PID "$pid" //F
done
```

## Test & static analysis / テスト・静的解析

```bash
export PATH="$PATH:/c/flutter/bin"
flutter analyze
flutter test
```
Both were verified clean in this environment (`flutter analyze`: no
issues; `flutter test`: 1/1 passed — a smoke test that renders the login
screen with Supabase mock-initialized).

いずれもこの環境で問題無く通ることを確認済み（`flutter analyze`: 問題無し、
`flutter test`: 1/1件パス — Supabaseをモック初期化してログイン画面を
描画するスモークテスト）。

## Run (human path): native builds / 実行（人間向け）: ネイティブビルド

Requires a display / device this environment doesn't have — untested here,
documented from the project's own README:
```bash
flutter run --flavor passenger -t lib/main_passenger.dart   # Android/iOS
flutter run -d windows                                       # Windows desktop
flutter run                                                   # defaults to passenger flavor
```

この環境には無いディスプレイ・実機が必要なため未検証 — プロジェクトの
READMEを元に記載のみ:
```bash
flutter run --flavor passenger -t lib/main_passenger.dart   # Android/iOS
flutter run -d windows                                       # Windowsデスクトップ
flutter run                                                   # デフォルトは乗客用flavor
```

## Gotchas / 落とし穴

- **`flutter: command not found`** in the Bash tool even though Flutter is
  installed — the Bash tool's shell doesn't inherit the same PATH as a
  normal terminal here. Always `export PATH="$PATH:/c/flutter/bin"` first.

  Flutterがインストール済みなのにBashツールで**`flutter: command not
  found`** になる — Bashツールのシェルは通常のターミナルと同じPATHを
  引き継がない。必ず先に `export PATH="$PATH:/c/flutter/bin"` すること。

- **`python3 -m http.server` silently fails** (curl gets connection
  refused, no error printed) — `python3` on this machine resolves to a
  Windows Store stub, not a real interpreter. Use `driver.mjs serve`
  (Node) instead.

  **`python3 -m http.server` が無言で失敗する**（curlが接続拒否になるが
  エラーは出力されない）— このマシンの `python3` はWindows Storeの
  スタブを指しており、実体のインタプリタではない。代わりに
  `driver.mjs serve`（Node製）を使うこと。

- **Google Maps won't render / console shows no map** — `web/index.html`
  is generated (gitignored) from `web/index.html.template` by
  `tool/gen_web_index.sh`, which reads `GOOGLE_MAPS_API_KEY` from `.env`.
  Forgetting to run that script after a fresh checkout, or after changing
  the key, leaves a stale or missing key baked into the build.

  **Google Mapsが表示されない/コンソールに地図が出ない** —
  `web/index.html` は `tool/gen_web_index.sh` が `web/index.html.template`
  から生成する（gitignore対象）ファイルで、`.env` の `GOOGLE_MAPS_API_KEY`
  を読み込む。新規clone直後やキー変更後にこのスクリプトの実行を忘れると、
  古い/存在しないキーがビルドに焼き込まれたままになる。

- **No fixed "app ready" signal from Flutter web** — `driver.mjs` waits
  for `networkidle` plus a flat 3s timeout before screenshotting/clicking.
  This was reliable in testing but is a guess, not a hook into the
  framework; bump the timeout if screenshots look like they caught the
  app mid-boot (blank canvas).

  **Flutter Webには固定の「起動完了」シグナルが無い** — `driver.mjs` は
  `networkidle` 待ち＋固定3秒のタイムアウトを経てからスクリーンショット/
  クリックする。検証中は安定していたが、あくまで経験則でフレームワーク
  側のフックではない。スクリーンショットがアプリ起動途中（空白の
  canvas）を捉えているようならタイムアウトを伸ばすこと。

- **Location permission banner on the passenger home screen** is expected
  in this headless environment — Chromium has no real GPS, so the app
  shows "位置情報の権限が許可されていません" and lets you pick pickup by
  tapping the map instead. Not a bug to "fix" when driving headlessly.

  **乗客用ホーム画面の位置情報許可バナー**は、このヘッドレス環境では
  出て当然 — Chromiumには実際のGPSが無いため、アプリは
  「位置情報の権限が許可されていません」と表示し、代わりに地図タップで
  乗車地点を選べるようにする。ヘッドレス操作時に「直すべきバグ」では
  ない。

- **Pixel-coordinate clicks shift with locale** — the app is localized
  (pt default, ja supported; see `bilingual-comments` skill's "neither"
  section). Translated text is a different length, which can shift where
  a button/banner lands vertically (the login screen's dev-bypass button
  sits at y≈607 in ja but y≈616 in pt on this machine, due to the dev
  banner wrapping to a different number of lines). This machine's OS
  locale is Japanese, so a fresh headless launch defaults to ja unless
  you click the language-switcher (globe icon, top-right, ~(460, 28)) to
  change it. Always re-screenshot after any locale change before reusing
  saved coordinates.

  **ピクセル座標クリックは言語によってずれる** — アプリは多言語対応済み
  （デフォルトpt、ja対応 — `bilingual-comments` スキルの
  「どちらでもないもの」セクション参照）。翻訳後のテキストは長さが
  異なるため、ボタン/バナーの縦位置がずれることがある（このマシンでは
  ログイン画面の開発用バイパスボタンが、開発用バナーの折り返し行数の
  違いによりjaでy≈607、ptでy≈616になる）。このマシンのOS言語は日本語
  なので、ヘッドレス起動直後はjaがデフォルトになる（言語切り替え —
  右上の🌐アイコン、おおよそ(460, 28) — をクリックしない限り）。言語を
  変更した後は、保存済みの座標を再利用する前に必ずスクリーンショットを
  撮り直すこと。
