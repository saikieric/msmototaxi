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
   アプリは起動する（ログイン画面に「未接続」の案内が表示される）。
   If no Supabase project exists yet, the app still runs with placeholder
   values in `.env` — the login screen shows a "not connected" notice.

## 実行 / Running

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

- [x] Flutter土台（flavor分離、ルーティング、電話番号OTPログイン画面、
      乗客/ドライバーのホーム画面プレースホルダー）
      Flutter foundation (flavor split, routing, phone-OTP login screen,
      placeholder passenger/driver home screens)
- [ ] Supabaseプロジェクトの作成・スキーマ設計（users, drivers, rides等）
      Supabase project creation & schema design (users, drivers, rides, etc.)
- [ ] PostGISによる位置情報検索・マッチングロジック（Edge Functions）
      PostGIS-based location search & matching logic (Edge Functions)
- [ ] 地図・ルート検索（Mapbox / Google Maps）の統合
      Map & route search integration (Mapbox / Google Maps)
- [ ] 決済（Pix経由）
      Payments (via Pix)
- [ ] iOS flavor設定（Mac環境が必要）
      iOS flavor setup (requires a Mac)
