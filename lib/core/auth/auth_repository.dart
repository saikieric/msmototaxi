import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

/// Thin wrapper around Supabase Auth.
/// Supabase Authの薄いラッパー。
///
/// Phone OTP ([signInWithPhoneOtp] / [verifyPhoneOtp]) is the product path
/// for Registro and stays callable so the login screen can switch to it
/// once the SMS provider is configured. Until then the login button calls
/// [signInAnonymously], which creates a real session (`auth.uid()` is set)
/// without an email/password form. The [role] metadata is what
/// `handle_new_user` reads to insert `profiles` (and `driver_profiles`).
/// Registro向けの本経路は電話番号OTP（[signInWithPhoneOtp] /
/// [verifyPhoneOtp]）。SMSプロバイダ設定後にログイン画面をそちらへ
/// 切り替えられるよう、呼び出し可能なまま残す。それまではログインボタンが
/// [signInAnonymously] を呼ぶ。メール/パスワード欄なしで実セッション
/// （`auth.uid()` が設定される）を作る。[role] メタデータは
/// `handle_new_user` が `profiles`（および `driver_profiles`）を
/// 挿入するときに読む。
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  static AuthRepository get instance => AuthRepository(SupabaseConfig.client);

  User? get currentUser => _client.auth.currentUser;

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

  /// Creates an anonymous session. [role] must be `passenger` or `driver`
  /// — it is stored as user metadata so the signup trigger can branch.
  /// 匿名セッションを作る。[role] は `passenger` か `driver`。
  /// サインアップ時のトリガーが分岐できるよう、ユーザーメタデータに保存する。
  ///
  /// Anonymous sign-ins must be enabled in the Supabase dashboard
  /// (Authentication → Providers → Anonymous). No schema change: this hits
  /// the same `auth.users` insert as sign-up, which already runs
  /// `handle_new_user`.
  /// 匿名サインインは Supabase ダッシュボードで有効にする必要がある
  /// （Authentication → Providers → Anonymous）。スキーマ変更は不要。
  /// サインアップと同じ `auth.users` への insert になり、既存の
  /// `handle_new_user` が動く。
  Future<AuthResponse> signInAnonymously({required String role}) {
    return _client.auth.signInAnonymously(data: {'role': role});
  }

  Future<void> signOut() => _client.auth.signOut();
}
