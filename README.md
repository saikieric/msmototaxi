# MotoGo (ms_moto_taxi)

Registro市（サンパウロ州）向けのモトタクシー配車アプリ。乗客用・ドライバー用の2つのアプリを
1つのFlutterコードベースからflavorで分離ビルドする。詳しい背景・技術構成は
[../slides/slides.md](../slides/slides.md) を参照。

A ride-hailing app for moto-taxis in Registro, São Paulo state, Brazil. The
passenger and driver apps are built from a single Flutter codebase, separated
by build flavor. See [../slides/slides.md](../slides/slides.md) for the full
background and architecture.

## セットアップ / Setup

1. 依存関係を取得 / Fetch dependencies:
   ```
   flutter pub get
   ```
2. Supabaseプロジェクトの接続情報を設定 / Configure Supabase connection:
   ```
   cp .env.example .env
   ```
   `.env` に `SUPABASE_URL` と `SUPABASE_ANON_KEY` を設定する（Supabase
   Dashboard > Project Settings > API から取得）。`.env` は git 管理外。
   Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `.env` (from the
   Supabase Dashboard > Project Settings > API). `.env` is gitignored.

   Supabaseプロジェクトがまだ無い場合、`.env` はプレースホルダー値のままでも
   アプリは起動する。
   If no Supabase project exists yet, the app still runs with placeholder
   values in `.env`.

   既定のログインは電話番号OTP（下記「ログインについて」）。匿名サインインは
   `--dart-define=AUTH_ANONYMOUS=true` の開発/テスト用フォールバックで、
   使うときは Dashboard の Authentication > Sign In / Up > Anonymous で
   "Allow anonymous sign-ins" を有効にする。無効のままそのボタンを押すと失敗する。
   The default login is phone OTP (see "About login" below). Anonymous
   sign-in is a dev/test fallback behind `--dart-define=AUTH_ANONYMOUS=true`.
   When using it, turn on "Allow anonymous sign-ins" under Authentication >
   Sign In / Up > Anonymous. Without that, every tap of the anonymous
   button fails.

3. Google Maps APIキーを設定 / Configure the Google Maps API key:

   乗客用ホーム画面（地図＋配車依頼UI）はGoogle Maps SDKを使う。プラット
   フォームごとにキーの置き場所が異なる（Supabaseの`.env`と違い、静的な
   ネイティブ設定ファイルに直接書き込む必要がある）:
   The passenger home screen (map + ride-request UI) uses the Google Maps
   SDK. Unlike Supabase's `.env`, the key has to go into per-platform native
   config files:

   | プラットフォーム / Platform | ファイル / File | 備考 / Notes |
   |---|---|---|
   | Android | `android/local.properties`（`googleMaps.apiKey=`） | gitignore対象 / gitignored |
   | iOS | `ios/Runner/AppDelegate.swift`（`GMSServices.provideAPIKey(...)`） | 現状ソースに直書き。Macでの本設定時にxcconfig等への切り出しを検討 / currently inline in source; consider moving to an untracked xcconfig when set up on a Mac |
   | Web | `.env` の `GOOGLE_MAPS_API_KEY` から `web/index.html` を生成 | 下記参照 / see below |

   Google Cloud Consoleで「APIとサービス > 認証情報」からAPIキーを発行し、
   プラットフォームに応じて「Maps SDK for Android」「Maps SDK for iOS」
   「Maps JavaScript API」を有効化する。
   Get an API key from Google Cloud Console (APIs & Services > Credentials),
   enabling "Maps SDK for Android" / "Maps SDK for iOS" / "Maps JavaScript
   API" as appropriate.

   **Web版について** — `web/index.html` は静的HTMLでビルド時の変数展開が
   できないため、`.env`から直接読ませることができない。代わりに
   `web/index.html.template`（プレースホルダー入り、git管理対象）から、
   `.env`の`GOOGLE_MAPS_API_KEY`を埋め込んだ`web/index.html`（gitignore
   対象、実際のキーが入る）を生成するスクリプトを用意している:
   **About the web build** — `web/index.html` is static HTML with no
   build-time variable substitution, so it can't read `.env` directly.
   Instead, `web/index.html.template` (placeholder, tracked in git) is used
   to generate the real `web/index.html` (gitignored, has the real key) via
   a script:
   ```
   # Requires .env with GOOGLE_MAPS_API_KEY set. Re-run whenever that
   # value changes. Run in Git Bash (or any bash) — see tool/gen_web_index.sh.
   # GOOGLE_MAPS_API_KEYを設定した.envが必要。値を変更したら再実行すること。
   # Git Bash等のbashで実行（tool/gen_web_index.sh参照）。
   bash tool/gen_web_index.sh
   ```
   `flutter run -d chrome` / `flutter build web` の前に一度実行しておく。
   Run this once before `flutter run -d chrome` / `flutter build web`.

## 実行 / Running

### ログインについて（電話番号OTP） / About login (phone OTP)

ログインはブラジルの携帯番号（`+55`）にSMSコードを送って確認する。`signInWithPhoneOtp` は flavor の `role` をユーザーメタデータに渡すので、既存の `handle_new_user` が `profiles`（ドライバーなら `driver_profiles` も）を作る。SMSは Supabase Dashboard の Twilio Verify（Authentication → Providers → Phone）。Account SID / Auth Token / Verify Service SID はダッシュボードにだけ置き、リポジトリには置かない。`.env` が未設定（プレースホルダー）のときは送信ボタンは無効で、未接続と表示する。

匿名サインインは開発/テスト用のフォールバック。既定のビルドにはボタンが出ない。出すときは `--dart-define=AUTH_ANONYMOUS=true` を付け、Dashboard の Anonymous プロバイダも有効にする。

Login sends an SMS code to a Brazilian mobile number (`+55`) and verifies it. `signInWithPhoneOtp` passes the flavor's `role` as user metadata, so the existing `handle_new_user` trigger creates `profiles` (and `driver_profiles` for a driver). SMS is Twilio Verify in the Supabase Dashboard (Authentication → Providers → Phone). The Account SID, Auth Token, and Verify Service SID belong in the dashboard only, not in the repo. While `.env` is still the placeholder, submit stays disabled and the screen says the backend is not connected.

Anonymous sign-in is a dev/test fallback. The default build does not show that button. To show it, pass `--dart-define=AUTH_ANONYMOUS=true` and enable the Anonymous provider in the Dashboard.

flavorごとにエントリポイントが分かれている（`lib/main_passenger.dart` /
`lib/main_driver.dart`）。`lib/main.dart` は開発時の簡便のため乗客用flavorの
エイリアスになっている。
Each flavor has its own entrypoint (`lib/main_passenger.dart` /
`lib/main_driver.dart`). `lib/main.dart` is a passenger-flavor alias kept for
convenience during early development.

```
# 乗客用アプリ / Passenger app
flutter run --flavor passenger -t lib/main_passenger.dart

# ドライバー用アプリ / Driver app
flutter run --flavor driver -t lib/main_driver.dart

# 開発時の簡易起動（乗客用と同じ） / Quick dev run (same as passenger)
flutter run

# 匿名サインインのボタンも出す（既定は電話番号OTPのみ）
# Also show the anonymous sign-in button (default is phone OTP only)
flutter run -d chrome -t lib/main_passenger.dart --dart-define=AUTH_ANONYMOUS=true
```

### Android

`android/app/build.gradle.kts` に `passenger` / `driver` の
`productFlavors`（applicationId接尾辞・表示名違い）を設定済み。両方を
同一端末に共存インストールできる。
Android flavors (`passenger` / `driver`, differing by applicationId suffix
and display name) are already configured in
`android/app/build.gradle.kts`, so both can be installed side by side on the
same device.

### iOS

現時点でiOSのXcodeスキーム（Runner-passenger / Runner-driver 等）は未作成。
このリポジトリはWindows環境で開発しているためXcodeでの検証ができず、
安全に自動生成できなかった。Macで以下の手順が必要:
iOS Xcode schemes (e.g. `Runner-passenger` / `Runner-driver`) haven't been
created yet — this repo is being developed on Windows, so there's no Xcode
available here to safely generate/verify them. On a Mac, do the following:

1. Xcodeで `ios/Runner.xcodeproj` を開く / Open `ios/Runner.xcodeproj` in Xcode
2. Runner ターゲットに `Configurations` を複製し、flavorごとの
   Debug/Release/Profile構成を作る（例: `Debug-passenger`, `Debug-driver` ...）
   Duplicate the target's `Configurations` to create per-flavor
   Debug/Release/Profile configs
3. 各構成に `FLUTTER_TARGET` ビルド設定を追加し、対応する
   `lib/main_passenger.dart` / `lib/main_driver.dart` を指す
   Add a `FLUTTER_TARGET` build setting per configuration pointing at the
   matching `lib/main_*.dart`
4. 対応するXcodeスキームを作成し、上記の構成に紐付ける
   Create matching Xcode schemes tied to those configurations

参考 / Reference: https://docs.flutter.dev/deployment/flavors

## テスト / Testing

```
flutter analyze
flutter test
```

## 現在の状態 / Current status

- [x] Flutter土台（flavor分離、ルーティング、乗客/ドライバーのホーム画面）
      Flutter foundation (flavor split, routing, passenger/driver home screens)
- [x] Supabaseプロジェクト作成・DBスキーマ適用（profiles, driver_profiles,
      driver_locations, rides + PostGIS + RLS + Realtime）。`sa-east-1`
      （São Paulo）にてホスティング。
      Supabase project created & DB schema applied (profiles,
      driver_profiles, driver_locations, rides + PostGIS + RLS + Realtime).
      Hosted in `sa-east-1` (São Paulo).
- [x] 乗客用ホーム画面: Google Mapsで乗車地点（現在地/ドラッグ）・降車地点
      （タップ）を選択するUI。配車依頼の送信自体はまだスタブ（下記参照）。
      Passenger home screen: Google Maps UI to pick a pickup point (device
      location / draggable) and dropoff point (tap). Actually submitting the
      ride request is still stubbed (see below).
- [ ] 電話番号OTPのダッシュボード設定（Authentication → Providers → Phone
      で Twilio Verify。Account SID、Auth Token、Verify Service SID）。
      アプリ側の送信/確認は実装済み（上記「ログインについて」参照）。
      Twilio Verify credentials in the Supabase Dashboard
      (Authentication → Providers → Phone: Account SID, Auth Token,
      Verify Service SID). The app already sends and verifies the code
      (see "About login" above).
- [ ] 配車依頼の実データ書き込み・PostGISによるマッチングロジック
      （Edge Functions）。認証は電話番号OTP（または
      `--dart-define=AUTH_ANONYMOUS=true` の匿名セッション）で
      `auth.uid()` を満たす。残るのはマッチング。
      Actually writing ride requests & PostGIS-based matching logic (Edge
      Functions). Auth already supplies `auth.uid()` via phone OTP, or via
      the anonymous session when built with
      `--dart-define=AUTH_ANONYMOUS=true`. Matching is what remains.
- [ ] 決済（Pix経由）
      Payments (via Pix)
- [ ] iOS flavor設定（Mac環境が必要）
      iOS flavor setup (requires a Mac)
