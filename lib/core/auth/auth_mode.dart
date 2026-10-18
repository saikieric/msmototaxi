/// Compile-time switch for the anonymous sign-in fallback.
/// 匿名サインインのフォールバックを切り替える、コンパイル時フラグ。
///
/// Phone OTP is the default. Pass `--dart-define=AUTH_ANONYMOUS=true` to
/// also show the anonymous button, for local tests when Twilio Verify is
/// not configured yet. Any value other than `true` leaves it off.
/// 既定は電話番号OTP。Twilio Verify が未設定のローカル確認では
/// `--dart-define=AUTH_ANONYMOUS=true` を付けると匿名ボタンも出る。
/// `true` 以外ではオフ。
library;

const bool kAnonymousAuthFallback = bool.fromEnvironment('AUTH_ANONYMOUS');

/// Seconds to wait before another SMS, matching Supabase's default phone
/// rate limit (Authentication → Rate Limits). The server message wins when
/// it names a different delay.
/// 次のSMSまでの待ち秒数。Supabaseの電話番号レート制限の既定
/// （Authentication → Rate Limits）に合わせる。サーバー文言が別の秒数を
/// 示していればそちらを使う。
const int kSmsResendCooldownSeconds = 60;
