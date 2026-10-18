import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/driver/home/driver_home_screen.dart';
import '../../features/passenger/home/passenger_home_screen.dart';
import '../../flavors.dart';
import '../auth/auth_state.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStateAsync = ref.watch(authStateProvider);
  final flavor = AppConfig.instance.flavor;
  final homePath = switch (flavor) {
    Flavor.passenger => '/passenger',
    Flavor.driver => '/driver',
  };

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      // While the initial auth check is still in flight, don't redirect yet.
      // 初回の認証チェック中はまだリダイレクトしない。
      if (authStateAsync.isLoading) return null;

      final isSignedIn = ref.read(currentUserProvider) != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isSignedIn && !isLoggingIn) return '/login';
      if (isSignedIn && isLoggingIn) return homePath;
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/passenger',
        builder: (context, state) => const PassengerHomeScreen(),
      ),
      GoRoute(
        path: '/driver',
        builder: (context, state) => const DriverHomeScreen(),
      ),
    ],
  );
});

/// Bridges a Riverpod provider to go_router's [Listenable]-based
/// `refreshListenable`, so route redirects re-evaluate on auth changes.
/// Riverpod の provider を go_router の [Listenable] ベースの
/// `refreshListenable` に橋渡しし、認証状態の変化時にリダイレクト判定を
/// 再評価させる。
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}
