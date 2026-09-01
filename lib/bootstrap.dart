import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/supabase/supabase_config.dart';
import 'flavors.dart';

/// Shared startup logic for both flavors: init Supabase, then run the app.
/// 両flavor共通の起動処理: Supabaseを初期化してからアプリを起動する。
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize(flavor: flavor);
  await SupabaseConfig.initialize();

  runApp(const ProviderScope(child: MotoGoApp()));
}
