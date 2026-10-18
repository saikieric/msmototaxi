import 'package:flutter_test/flutter_test.dart';
import 'package:msmototaxi/core/auth/otp_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps resend rate limits and reads the wait from the message', () {
    const error = AuthException(
      'For security purposes, you can only request this after 47 seconds.',
      statusCode: '429',
      code: 'over_sms_send_rate_limit',
    );

    expect(
      classifyOtpFailure(error, attempt: OtpAttempt.send),
      OtpFailure.resendCooldown,
    );
    expect(cooldownSecondsFromMessage(error.message), 47);
  });

  test('does not treat a 429 on verify as a resend cooldown', () {
    const error = AuthException(
      'For security purposes, you can only request this after 47 seconds.',
      statusCode: '429',
      code: 'over_request_rate_limit',
    );

    expect(
      classifyOtpFailure(error, attempt: OtpAttempt.verify),
      isNot(OtpFailure.resendCooldown),
    );
  });

  test('maps a wrong or expired code on verify', () {
    const error = AuthException(
      'Token has expired or is invalid',
      statusCode: '403',
      code: 'otp_expired',
    );

    expect(
      classifyOtpFailure(error, attempt: OtpAttempt.verify),
      OtpFailure.wrongCode,
    );
  });

  test('maps an invalid number on send, not every provider failure', () {
    const invalid = AuthException(
      'Error sending confirmation OTP to provider: 60200: Invalid parameter',
      statusCode: '422',
      code: 'sms_send_failed',
    );
    const other = AuthException(
      'Error sending confirmation OTP to provider: 20003: Authenticate',
      statusCode: '500',
      code: 'sms_send_failed',
    );

    expect(
      classifyOtpFailure(invalid, attempt: OtpAttempt.send),
      OtpFailure.invalidPhone,
    );
    expect(
      classifyOtpFailure(other, attempt: OtpAttempt.send),
      OtpFailure.other,
    );
    expect(
      classifyOtpFailure(
        const AuthException(
          'Invalid phone number format (E.164 required)',
          code: 'validation_failed',
        ),
        attempt: OtpAttempt.send,
      ),
      OtpFailure.invalidPhone,
    );
  });
}
