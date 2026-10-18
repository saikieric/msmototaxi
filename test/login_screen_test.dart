// Widget tests for LoginScreen's phone-OTP flow: the send button disables
// while a request is pending, a failure is shown inline, and the role
// passed to AuthRepository.signInWithPhoneOtp matches the active flavor.
//
// LoginScreenの電話番号OTPフローに関するウィジェットテスト: 送信中は
// 送信ボタンが無効になること、失敗は画面内に表示されること、そして
// AuthRepository.signInWithPhoneOtp に渡される role が現在の flavor と
// 一致することを確認する。

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
/// [signInWithPhoneOtp] and lets a test control exactly when (and whether
/// successfully) that call completes.
/// [signInWithPhoneOtp]に渡された[role]を記録し、その呼び出しがいつ・
/// 成功/失敗のどちらで完了するかをテスト側から制御できるようにした
/// 偽の[AuthRepository]。
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(Supabase.instance.client);

  String? capturedRole;
  String? capturedPhone;
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
  Future<void> signInWithPhoneOtp({
    required String phone,
    required String role,
  }) async {
    capturedRole = role;
    capturedPhone = phone;
    await _completer.future;
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

    // SupabaseConfig.isConfigured must be true here, otherwise _sendCode
    // short-circuits before ever calling AuthRepository — use non-placeholder
    // values so these tests exercise the real send path.
    // ここでは SupabaseConfig.isConfigured が true である必要がある。
    // そうでないと_sendCodeがAuthRepositoryを呼ぶ前に早期returnしてしまう —
    // 実際の送信経路を検証するため、プレースホルダーではない値を使う。
    dotenv.testLoad(
      fileInput:
          'SUPABASE_URL=https://fake.supabase.co\n'
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

  Future<void> enterMobileAndTapSend(WidgetTester tester) async {
    // DDD 13 + a mobile (leading 9). The field's +55 prefix is decoration;
    // the controller stores the national number.
    // 市外局番13 + 携帯（先頭9）。+55 は装飾で、コントローラには国内番号が
    // 入る。
    await tester.enterText(find.byType(TextField), '13999999999');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'コードを送信'));
  }

  testWidgets('disables the send button while the OTP request is pending', (
    WidgetTester tester,
  ) async {
    final fake = _FakeAuthRepository();
    await pumpLoginScreen(
      tester,
      flavor: Flavor.passenger,
      authRepository: fake,
    );

    await enterMobileAndTapSend(tester);
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

  testWidgets('shows an error when sending the code fails', (
    WidgetTester tester,
  ) async {
    final fake = _FakeAuthRepository()..failure = Exception('network error');
    await pumpLoginScreen(
      tester,
      flavor: Flavor.passenger,
      authRepository: fake,
    );

    await enterMobileAndTapSend(tester);
    await tester.pump();
    fake.complete();
    await tester.pumpAndSettle();

    expect(find.textContaining('network error'), findsOneWidget);
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
    await enterMobileAndTapSend(tester);
    await tester.pump();
    passengerFake.complete();
    await tester.pumpAndSettle();
    expect(passengerFake.capturedRole, 'passenger');
    expect(passengerFake.capturedPhone, '+5513999999999');

    final driverFake = _FakeAuthRepository();
    await pumpLoginScreen(
      tester,
      flavor: Flavor.driver,
      authRepository: driverFake,
    );
    await enterMobileAndTapSend(tester);
    await tester.pump();
    driverFake.complete();
    await tester.pumpAndSettle();
    expect(driverFake.capturedRole, 'driver');
  });
}
