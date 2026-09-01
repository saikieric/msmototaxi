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
