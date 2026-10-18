// Smoke test: with Supabase unconfigured (placeholder .env) and no signed-in
// user, the app should land on the login screen without crashing.
//
// スモークテスト: Supabase 未設定（.env がプレースホルダー）かつ未ログイン状態でも、
// クラッシュせずログイン画面が表示されることを確認する。

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msmototaxi/app.dart';
import 'package:msmototaxi/core/locale/locale_controller.dart';
import 'package:msmototaxi/flavors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    // supabase_flutter persists the session via shared_preferences, which
    // needs an in-memory mock under `flutter test` (no real platform plugin).
    // supabase_flutter はセッションをshared_preferencesで永続化するため、
    // `flutter test` 環境（実プラットフォームプラグインなし）ではインメモリの
    // モックが必要。
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    // SupabaseConfig reads dotenv.env, so it must be initialized even
    // though this test doesn't load a real .env file.
    // SupabaseConfig は dotenv.env を参照するため、実際の .env を
    // 読み込まない場合でも初期化しておく必要がある。
    dotenv.testLoad(fileInput: '');

    AppConfig.initialize(flavor: Flavor.passenger);
    // Placeholder values — no network calls are made by this smoke test.
    // ネットワーク通信は発生しないため、実際のプロジェクト値は不要。
    await Supabase.initialize(
      url: 'https://your-project-ref.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('Shows the login screen on first launch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Force a locale so the assertion below doesn't depend on the
          // test runner's own default locale (usually en_US, which this
          // app doesn't ship a translation for).
          // 下のアサーションがテストランナー自体のデフォルト言語
          // （通常en_US。このアプリは対応翻訳を持たない）に依存しないよう、
          // 言語を固定する。
          localeControllerProvider.overrideWith(
            () => LocaleController(prefs, const Locale('ja')),
          ),
        ],
        child: const MotoGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MotoGo'), findsOneWidget);
    expect(find.text('コードを送信'), findsOneWidget);
    expect(find.text('携帯電話番号'), findsOneWidget);
    // Anonymous sign-in is a dart-define fallback and stays off by default.
    // 匿名サインインは dart-define のフォールバックで、既定では出さない。
    expect(find.text('匿名でログイン（テスト）'), findsNothing);
    // dotenv.testLoad left the env empty, so the button must not navigate.
    // dotenv.testLoad で env は空のまま。ボタンは画面遷移させない。
    expect(
      find.text('バックエンド未接続です。.env に Supabase の設定を入れてください。'),
      findsOneWidget,
    );
  });

  testWidgets('Invalid phone shows a localized error and does not send', (
    WidgetTester tester,
  ) async {
    // Non-placeholder values make the submit button active. The number
    // below fails client-side, so Supabase is never called.
    // プレースホルダー以外の値で送信ボタンを有効にする。下の番号は
    // クライアント側で弾くので、Supabaseは呼ばれない。
    dotenv.testLoad(
      fileInput:
          'SUPABASE_URL=https://example.supabase.co\n'
          'SUPABASE_ANON_KEY=sb_publishable_test\n',
    );
    addTearDown(() => dotenv.testLoad(fileInput: ''));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeControllerProvider.overrideWith(
            () => LocaleController(prefs, const Locale('ja')),
          ),
        ],
        child: const MotoGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('コードを送信'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '番号が正しくありません。市外局番付きのブラジルの携帯電話番号を入力してください（例: 13 99999-9999）。',
      ),
      findsOneWidget,
    );
    expect(find.text('SMSコード'), findsNothing);
  });
}
