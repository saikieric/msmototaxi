// Smoke test: with Supabase unconfigured (placeholder .env) and no signed-in
// user, the app should land on the login screen without crashing.
//
// スモークテスト: Supabase 未設定（.env がプレースホルダー）かつ未ログイン状態でも、
// クラッシュせずログイン画面が表示されることを確認する。

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msmototaxi/app.dart';
import 'package:msmototaxi/flavors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    // supabase_flutter persists the session via shared_preferences, which
    // needs an in-memory mock under `flutter test` (no real platform plugin).
    // supabase_flutter はセッションをshared_preferencesで永続化するため、
    // `flutter test` 環境（実プラットフォームプラグインなし）ではインメモリの
    // モックが必要。
    SharedPreferences.setMockInitialValues({});

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
      const ProviderScope(child: MotoGoApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('MotoGo'), findsOneWidget);
    expect(find.text('ログイン'), findsOneWidget);
  });
}
