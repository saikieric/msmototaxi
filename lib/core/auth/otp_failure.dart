import 'package:supabase_flutter/supabase_flutter.dart';

/// Which Auth call failed, so the same Supabase code can mean different
/// things on send vs verify.
/// 失敗したAuth呼び出し。同じSupabaseのコードでも送信時と確認時で
/// 意味が変わるため。
enum OtpAttempt { send, verify }

/// Login failures the screen maps to a localized sentence.
/// ログイン画面がローカライズした文に対応づける失敗種別。
enum OtpFailure { invalidPhone, wrongCode, resendCooldown, other }

/// Classifies a Supabase [AuthException] from phone OTP.
/// 電話番号OTPの [AuthException] を分類する。
///
/// Supabase uses `otp_expired` for both a wrong code and an expired one,
/// and `over_sms_send_rate_limit` when the resend window has not elapsed.
/// Twilio Verify's "invalid To" comes back as `sms_send_failed` or
/// `validation_failed`.
/// Supabaseはコード違いと期限切れの両方に `otp_expired` を使い、
/// 再送間隔が残っているときは `over_sms_send_rate_limit` を返す。
/// Twilio Verifyの「Toが不正」は `sms_send_failed` か
/// `validation_failed` になる。
OtpFailure classifyOtpFailure(AuthException error, {required OtpAttempt attempt}) {
  final code = error.code ?? '';
  final message = error.message.toLowerCase();

  if (attempt == OtpAttempt.send && _isResendCooldown(code, message, error.statusCode)) {
    return OtpFailure.resendCooldown;
  }
  if (attempt == OtpAttempt.verify && _isWrongCode(code, message)) {
    return OtpFailure.wrongCode;
  }
  if (attempt == OtpAttempt.send && _isInvalidPhone(code, message)) {
    return OtpFailure.invalidPhone;
  }
  return OtpFailure.other;
}

/// Seconds named in a rate-limit message, if any.
/// レート制限の文言に秒数が含まれていれば、その秒数。
int? cooldownSecondsFromMessage(String message) {
  final match = RegExp(r'(\d+)\s*seconds?').firstMatch(message.toLowerCase());
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

bool _isResendCooldown(String code, String message, String? statusCode) {
  if (statusCode == '429') return true;
  if (code == 'over_sms_send_rate_limit' || code == 'over_request_rate_limit') {
    return true;
  }
  return message.contains('only request this after') ||
      message.contains('rate limit') ||
      message.contains('max send attempts') ||
      message.contains('too many');
}

bool _isWrongCode(String code, String message) {
  if (code == 'otp_expired') return true;
  return message.contains('expired or is invalid') ||
      message.contains('invalid otp') ||
      message.contains('token has expired') ||
      message.contains('verification check');
}

bool _isInvalidPhone(String code, String message) {
  if (code == 'validation_failed') return true;
  if (message.contains('invalid phone') ||
      message.contains('phone number format') ||
      message.contains('not a valid phone')) {
    return true;
  }
  // Twilio 21211 / 60200: the `To` number was rejected.
  // Twilio 21211 / 60200: `To` の番号が拒否された。
  if (code == 'sms_send_failed') {
    return message.contains('21211') ||
        message.contains('60200') ||
        message.contains('invalid parameter');
  }
  return false;
}
