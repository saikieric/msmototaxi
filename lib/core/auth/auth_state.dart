import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

/// Streams Supabase auth state changes so the router / UI can react to
/// sign-in and sign-out.
/// Supabaseの認証状態の変化をストリームで流し、ルーターやUIが
/// ログイン／ログアウトに反応できるようにする。
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange;
});

/// The current signed-in user, or null if signed out.
/// 現在ログイン中のユーザー。未ログインの場合は null。
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).valueOrNull;
  return authState?.session?.user ?? SupabaseConfig.client.auth.currentUser;
});
