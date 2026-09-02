import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Development-only flag that lets the router treat the user as "signed in"
/// without a real Supabase session, so screens past the login page can be
/// built/tested before phone-OTP auth is fully wired up (SMS provider
/// configured in the Supabase Dashboard, etc.).
///
/// 開発用フラグ。実際のSupabaseセッションが無くても、ルーターが
/// 「ログイン済み」として扱えるようにする。電話番号OTP認証が
/// 本設定（Supabase DashboardでのSMSプロバイダ設定等）される前でも、
/// ログイン画面より先の画面を作成・確認できるようにするための仕組み。
///
/// TODO: Remove this once real phone-OTP sign-in is wired up end-to-end.
/// TODO: 電話番号OTPログインが本物として動くようになったら削除する。
final devAuthBypassProvider = StateProvider<bool>((ref) => false);
