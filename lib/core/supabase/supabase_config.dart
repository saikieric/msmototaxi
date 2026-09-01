import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads Supabase connection settings from the `.env` file (see
/// `.env.example`) and initializes the Supabase client.
/// `.env`（`.env.example` 参照）からSupabaseの接続設定を読み込み、
/// Supabaseクライアントを初期化する。
///
/// Until a real Supabase project is created and `.env` is filled in, [url]
/// and [anonKey] fall back to placeholder values and [isConfigured] is
/// false — screens can use that to show a "backend not connected yet"
/// state instead of crashing.
/// 実際のSupabaseプロジェクトが作成され `.env` が設定されるまでは、[url] と
/// [anonKey] はプレースホルダー値になり [isConfigured] は false になる。
/// 画面側はこれを使って、クラッシュさせる代わりに「バックエンド未接続」の
/// 状態を表示できる。
class SupabaseConfig {
  SupabaseConfig._();

  static const _placeholderUrl = 'https://your-project-ref.supabase.co';
  static const _placeholderAnonKey = 'your-anon-key';

  static String get url =>
      dotenv.maybeGet('SUPABASE_URL') ?? _placeholderUrl;

  static String get anonKey =>
      dotenv.maybeGet('SUPABASE_ANON_KEY') ?? _placeholderAnonKey;

  /// Whether `.env` has been filled in with real project values.
  static bool get isConfigured =>
      url != _placeholderUrl && anonKey != _placeholderAnonKey;

  static Future<void> initialize() async {
    // Loaded as an asset (see pubspec.yaml `assets: - .env`). Missing keys
    // just fall back to the placeholders above.
    await dotenv.load(fileName: '.env');

    await Supabase.initialize(
      url: url,
      // supabase_flutter renamed `anonKey` -> `publishableKey`; we still
      // read it from the SUPABASE_ANON_KEY env var below since that's the
      // label Supabase's dashboard currently shows.
      // supabase_flutter は `anonKey` を `publishableKey` に改称した。
      // ダッシュボード表示に合わせ、.env の変数名は SUPABASE_ANON_KEY のまま使う。
      publishableKey: anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
