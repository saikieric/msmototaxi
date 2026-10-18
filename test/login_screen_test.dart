// Widget tests for LoginScreen's sign-in flow: button disabling while a
// sign-in is pending, the failure snackbar, and that the role passed to
// AuthRepository.signInAnonymously matches the active flavor.
//
// LoginScreenのサインインフローに関するウィジェットテスト: サインイン中の
// ボタン無効化、失敗時のスナックバー表示、そしてAuthRepository.
// signInAnonymouslyに渡されるroleが現在のflavorと一致することを確認する。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msmototaxi/core/auth/auth_repository.dart';
import 'package:msmototaxi/core/locale/locale_controller.dart';
import 'package:msmototaxi/features/auth/login_screen.dart';
import 'package:msmototaxi/flavors.dart';
import 'package:msmototaxi/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake [AuthRepository] that records the [role] passed to
/// [signInAnonymously] and lets a test control exactly when (and whether
/// successfully) that call completes.
/// [signInAnonymously]に渡された[role]を記録し、その呼び出しがいつ・
/// 成功/失敗のどちらで完了するかをテスト側から制御できるようにした
/// 偽の[AuthRepository]。
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(Supabase.instance.client);

  String? capturedRole;
  Object? failure;
  final _completer = Completer<void>();

  void complete() {
    if (failure != null) {
      _completer.completeError(failure!);
    } else {
      _completer.complete();
    }
  }

  @override
  Future<AuthResponse> signInAnonymously({required String role}) async {
    capturedRole = role;
    await _completer.future;
    return AuthResponse();
  }
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    // supabase_flutter persists the session via shared_preferences, which
    // needs an in-memory mock under `flutter test` (no real platform plugin)
    // — same reasoning as test/widget_test.dart.
    // supabase_flutter はセッションをshared_preferencesで永続化するため、
    // `flutter test` 環境ではインメモリのモックが必要
    // — test/widget_test.dartと同様の理由。
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    // SupabaseConfig.isConfigured must be true here, otherwise _signIn
    // short-circuits before ever calling AuthRepository — use non-placeholder
    // values so these tests exercise the real sign-in path.
    // ここでは SupabaseConfig.isConfigured が true である必要がある。
    // そうでないと_signInがAuthRepositoryを呼ぶ前に早期returnしてしまう —
    // 実際のサインイン経路を検証するため、プレースホルダーではない値を使う。
    dotenv.testLoad(
      fileInput: 'SUPABASE_URL=https://fake.supabase.co\n'
          'SUPABASE_ANON_KEY=fake-anon-key',
    );
    await Supabase.initialize(
      url: 'https://fake.supabase.co',
      publishableKey: 'fake-anon-key',
    );
  });

  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    required Flavor flavor,
    required AuthRepository authRepository,
  }) async {
    AppConfig.initialize(flavor: flavor);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          // LoginScreen's AppBar includes LanguageSwitcherButton, which
          // watches this provider — same override bootstrap.dart builds
          // from a real SharedPreferences instance at startup.
          // LoginScreenのAppBarにはLanguageSwitcherButtonが含まれ、これが
          // このproviderをwatchする — bootstrap.dartが起動時に実際の
          // SharedPreferencesインスタンスから構築するのと同じoverride。
          localeControllerProvider.overrideWith(
            () => LocaleController(prefs, const Locale('ja')),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('disables the login button while sign-in is pending', (
    WidgetTester tester,
  ) async {
    final fake = _FakeAuthRepository();
    await pumpLoginScreen(
      tester,
      flavor: Flavor.passenger,
      authRepository: fake,
    );

    await tester.tap(find.byType(FilledButton));
    // A single pump, not pumpAndSettle — the pending state shows an
    // indeterminate CircularProgressIndicator that never settles.
    // pumpAndSettleではなく1回だけpumpする — 保留中の状態は
    // 終了しないインジケータ（CircularProgressIndicator）を表示するため。
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    fake.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows a snackbar when sign-in fails', (
    WidgetTester tester,
  ) async {
    final fake = _FakeAuthRepository()..failure = Exception('network error');
    await pumpLoginScreen(
      tester,
      flavor: Flavor.passenger,
      authRepository: fake,
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    fake.complete();
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('passes the role matching the active flavor', (
    WidgetTester tester,
  ) async {
    final passengerFake = _FakeAuthRepository();
    await pumpLoginScreen(
      tester,
      flavor: Flavor.passenger,
      authRepository: passengerFake,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    passengerFake.complete();
    await tester.pumpAndSettle();
    expect(passengerFake.capturedRole, 'passenger');

    final driverFake = _FakeAuthRepository();
    await pumpLoginScreen(
      tester,
      flavor: Flavor.driver,
      authRepository: driverFake,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    driverFake.complete();
    await tester.pumpAndSettle();
    expect(driverFake.capturedRole, 'driver');
  });
}
