import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/locale/locale_controller.dart';
import 'core/supabase/supabase_config.dart';
import 'flavors.dart';

/// Shared startup logic for both flavors: init Supabase, load the
/// persisted language choice (if any), then run the app.
/// 両flavor共通の起動処理: Supabaseを初期化し、永続化された言語選択
/// （あれば）を読み込んでからアプリを起動する。
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize(flavor: flavor);
  await SupabaseConfig.initialize();

  // SharedPreferences is only accessible asynchronously, so the persisted
  // locale is read here (once, at startup) and handed to LocaleController
  // as its starting state via a provider override — see locale_controller.dart.
  // SharedPreferencesは非同期でしかアクセスできないため、永続化された
  // 言語設定はここで（起動時に一度だけ）読み込み、providerのoverride経由で
  // LocaleControllerの初期stateとして渡す — locale_controller.dart参照。
  final prefs = await SharedPreferences.getInstance();
  final initialLocale = readPersistedLocale(prefs);

  runApp(
    ProviderScope(
      overrides: [
        localeControllerProvider.overrideWith(
          () => LocaleController(prefs, initialLocale),
        ),
      ],
      child: const MotoGoApp(),
    ),
  );
}
