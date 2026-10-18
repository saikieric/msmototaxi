import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

/// Thin wrapper around Supabase Auth.
/// Supabase Authの薄いラッパー。
///
/// Per slides.md, auth is by phone number or email (Supabase Auth). Phone
/// OTP is the primary path for Registro drivers/passengers; email is a
/// fallback (e.g. for testing).
/// slides.md の通り、認証は電話番号またはメール（Supabase Auth）。
/// Registroのドライバー・乗客には電話番号OTPを主経路とし、
/// メールはテスト用途などのフォールバックとする。
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  static AuthRepository get instance => AuthRepository(SupabaseConfig.client);

  User? get currentUser => _client.auth.currentUser;

  /// Creates a real (anonymous) Supabase session tagged with [role]
  /// ('passenger' or 'driver', from the running app flavor). The
  /// `handle_new_user` DB trigger reads this from `raw_user_meta_data` to
  /// create the matching `profiles` (and `driver_profiles`) row. This is
  /// the login screen's path to a signed-in session until Supabase's SMS
  /// provider is configured and [signInWithPhoneOtp] takes over.
  /// [role]（起動中のflavorに応じた 'passenger' または 'driver'）を付与した
  /// 実際の（匿名）Supabaseセッションを作成する。`handle_new_user`
  /// DBトリガーがこれを`raw_user_meta_data`から読み取り、対応する
  /// `profiles`（および`driver_profiles`）行を作成する。SupabaseのSMS
  /// プロバイダが設定され[signInWithPhoneOtp]に置き換わるまでは、
  /// ログイン画面がログイン済みセッションを得るための経路はこちら。
  ///
  /// TODO: [role] is entirely self-reported by the client — anyone can
  /// call this and claim 'driver' with no verification. Don't treat an
  /// anonymous session's role as proof of driver identity anywhere
  /// (RLS policies, UI trust decisions) until this is replaced by real
  /// phone-OTP verification. See the RLS note in CLAUDE.md.
  /// TODO: [role]はクライアントの完全な自己申告であり、誰でもこれを呼んで
  /// 'driver'を名乗れる（裏付けは無い）。実際の電話番号OTP認証に置き換わる
  /// までは、匿名セッションのroleをドライバー本人であることの証明として
  /// （RLSポリシーやUI側の信頼判断などで）扱わないこと。CLAUDE.mdのRLSに
  /// 関する記載も参照。
  Future<AuthResponse> signInAnonymously({required String role}) {
    return _client.auth.signInAnonymously(data: {'role': role});
  }

  /// Sends a one-time password to [phone] (E.164 format, e.g. +5513999999999).
  /// [phone]（E.164形式、例: +5513999999999）にワンタイムパスワードを送信する。
  Future<void> signInWithPhoneOtp(String phone) {
    return _client.auth.signInWithOtp(phone: phone);
  }

  /// Verifies the OTP code sent by [signInWithPhoneOtp].
  /// [signInWithPhoneOtp] で送信したOTPコードを検証する。
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String otp,
  }) {
    return _client.auth.verifyOTP(
      type: OtpType.sms,
      phone: phone,
      token: otp,
    );
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
