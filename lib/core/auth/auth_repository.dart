import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

/// Thin wrapper around Supabase Auth.
/// Supabase Authの薄いラッパー。
///
/// Phone OTP ([signInWithPhoneOtp] / [verifyPhoneOtp]) is the login path.
/// [signInWithPhoneOtp] sends `data: {role}` so a new `auth.users` row
/// carries the flavor in `raw_user_meta_data`. The existing
/// `handle_new_user` trigger reads that and inserts `profiles` (and
/// `driver_profiles` when the role is `driver`).
/// ログイン経路は電話番号OTP（[signInWithPhoneOtp] / [verifyPhoneOtp]）。
/// [signInWithPhoneOtp] は `data: {role}` を送り、新しい `auth.users` 行の
/// `raw_user_meta_data` に flavor を載せる。既存の `handle_new_user`
/// トリガーがそれを読んで `profiles` を挿入する（role が `driver` なら
/// `driver_profiles` も）。
///
/// [signInAnonymously] keeps the anonymous-auth session
/// (`signInAnonymously(data: {role})`). The login screen shows that button
/// only for a build started with `--dart-define=AUTH_ANONYMOUS=true`.
/// [signInAnonymously] は匿名認証のセッション
/// （`signInAnonymously(data: {role})`）を残す。ログイン画面にそのボタンが
/// 出るのは `--dart-define=AUTH_ANONYMOUS=true` で起動したビルドだけ。
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  static AuthRepository get instance => AuthRepository(SupabaseConfig.client);

  User? get currentUser => _client.auth.currentUser;

  /// Sends an SMS OTP to [phone] (E.164, e.g. +5513999999999).
  /// [phone]（E.164、例: +5513999999999）にSMSのOTPを送る。
  ///
  /// [role] must be `passenger` or `driver`. Supabase stores it as user
  /// metadata on create; the signup trigger branches on it.
  /// [role] は `passenger` か `driver`。Supabaseは作成時にユーザー
  /// メタデータとして保存し、サインアップのトリガーがそれで分岐する。
  Future<void> signInWithPhoneOtp({
    required String phone,
    required String role,
  }) {
    return _client.auth.signInWithOtp(
      phone: phone,
      channel: OtpChannel.sms,
      data: {'role': role},
    );
  }

  /// Verifies the OTP code sent by [signInWithPhoneOtp].
  /// [signInWithPhoneOtp] で送信したOTPコードを検証する。
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String otp,
  }) {
    return _client.auth.verifyOTP(type: OtpType.sms, phone: phone, token: otp);
  }

  /// Creates a real anonymous Supabase session tagged with [role]
  /// ('passenger' or 'driver'). `handle_new_user` reads this from
  /// `raw_user_meta_data` and inserts `profiles` (and `driver_profiles`).
  /// The login screen calls this only when anonymous auth is compiled in
  /// (`--dart-define=AUTH_ANONYMOUS=true`).
  /// [role]（'passenger' または 'driver'）を付与した実際の匿名Supabase
  /// セッションを作成する。`handle_new_user` がこれを `raw_user_meta_data`
  /// から読み、`profiles`（および `driver_profiles`）を挿入する。
  /// ログイン画面がこれを呼ぶのは、匿名認証をコンパイルしたときだけ
  /// （`--dart-define=AUTH_ANONYMOUS=true`）。
  ///
  /// TODO: [role] is entirely self-reported by the client — anyone can
  /// call this and claim 'driver' with no verification. Phone OTP is the
  /// default login, but this fallback can still forge a role. Don't treat
  /// an anonymous session's role as proof of driver identity anywhere
  /// (RLS policies, UI trust decisions). See the RLS note in CLAUDE.md.
  /// TODO: [role]はクライアントの完全な自己申告であり、誰でもこれを呼んで
  /// 'driver'を名乗れる（裏付けは無い）。既定のログインは電話番号OTPだが、
  /// このフォールバックは今もroleを偽装できる。匿名セッションのroleを
  /// ドライバー本人であることの証明として（RLSポリシーやUI側の信頼判断
  /// などで）扱わないこと。CLAUDE.mdのRLSに関する記載も参照。
  Future<AuthResponse> signInAnonymously({required String role}) {
    return _client.auth.signInAnonymously(data: {'role': role});
  }

  Future<void> signOut() => _client.auth.signOut();
}

/// Riverpod provider for [AuthRepository], so widgets can get it via
/// `ref.read`/`ref.watch` instead of the static [AuthRepository.instance]
/// — this lets tests override it with a fake via `ProviderScope.overrides`.
/// [AuthRepository]用のRiverpodプロバイダ。ウィジェットから静的な
/// [AuthRepository.instance]の代わりに`ref.read`/`ref.watch`で取得できる
/// ようにする — `ProviderScope.overrides`でテスト用のフェイクに
/// 差し替え可能になる。
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(SupabaseConfig.client);
});
