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

   ログイン画面は匿名サインイン（`signInAnonymously`）を使うため、Supabase
   Dashboardで有効化しておく必要がある: Authentication > Sign In / Up >
   Anonymous を開き、"Allow anonymous sign-ins" を有効にする。これを
   有効にしないと、ログインボタンを押すたびに失敗する。
   The login screen uses anonymous sign-in (`signInAnonymously`), which
   must be enabled in the Supabase Dashboard: go to Authentication > Sign
   In / Up > Anonymous and turn on "Allow anonymous sign-ins". Without
   this, every tap of the login button fails.

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

### ログインについて（匿名認証） / About login (anonymous auth)

電話番号OTPログインは実装済み（[core/auth/auth_repository.dart](lib/core/auth/auth_repository.dart)）だが、Supabase
Dashboard側のSMSプロバイダ設定がまだ済んでいないため、現在ログイン画面の
「ログイン」ボタンは実際のOTP認証の代わりに、flavorをroleとして付与した
匿名Supabaseセッション（`signInAnonymously`）を作成する。これは実際の
Supabaseセッションであり、`handle_new_user`トリガーが通常のOTPログイン時
と同様に`profiles`/`driver_profiles`を作成する。SMS認証を設定したら、
この画面を実際の電話番号/OTPフローに切り替えること。
Phone-OTP login is implemented ([core/auth/auth_repository.dart](lib/core/auth/auth_repository.dart)), but since the
SMS provider isn't configured in the Supabase Dashboard yet, the login
screen's button instead creates an anonymous Supabase session
(`signInAnonymously`) tagged with the flavor as its role. This is a real
Supabase session — the `handle_new_user` trigger creates
`profiles`/`driver_profiles` just as it would for a real OTP login. Once
SMS auth is set up, switch the screen to the real phone/OTP flow.

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
- [ ] 電話番号OTP認証の本設定（Supabase DashboardでのSMSプロバイダ設定）。
      現在はログインボタンが代わりに匿名Supabaseセッションを作成する
      （上記「ログインについて」参照）。
      Real phone-OTP auth setup (SMS provider in Supabase Dashboard). Login
      currently creates an anonymous Supabase session instead (see "About
      login" above).
- [ ] 配車依頼の実データ書き込み・PostGISによるマッチングロジック
      （Edge Functions）。認証自体は匿名セッションで既に満たされている。
      Actually writing ride requests & PostGIS-based matching logic (Edge
      Functions). Auth itself is already satisfied via the anonymous
      session.
- [ ] 決済（Pix経由）
      Payments (via Pix)
- [ ] iOS flavor設定（Mac環境が必要）
      iOS flavor setup (requires a Mac)
