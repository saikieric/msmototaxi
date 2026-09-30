import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/dev_auth_bypass.dart';
import '../../../core/locale/language_switcher_button.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Driver home screen.
/// ドライバー用ホーム画面。
///
/// Placeholder for the online/offline toggle and incoming-ride-request UI.
/// Once Supabase exists, going online will start streaming this driver's
/// GPS position to Realtime (per slides.md "位置情報・地理検索") and
/// subscribe to incoming match offers from the matching Edge Function.
/// オンライン／オフライン切り替えと配車依頼受信UIのプレースホルダー。
/// Supabase構築後は、オンラインにするとこのドライバーのGPS位置情報を
/// Realtimeへ配信開始し（slides.md「位置情報・地理検索」参照）、
/// マッチング用Edge Functionからの依頼をsubscribeする。
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _isOnline = false;

  Future<void> _signOut() async {
    await AuthRepository.instance.signOut();
    // Also clear the dev bypass (see dev_auth_bypass.dart), otherwise the
    // router considers us still "signed in" and never returns to /login.
    // 開発用バイパス（dev_auth_bypass.dart参照）もクリアする。しないと
    // ルーターが「ログイン済み」のままとみなし、/login に戻れない。
    ref.read(devAuthBypassProvider.notifier).state = false;
  }

  void _showWazeStub() {
    final l10n = AppLocalizations.of(context)!;
    // TODO: Once ride matching exists, call launchWazeNavigation() with
    // the matched ride's pickup point here (see
    // core/navigation/waze_launcher.dart and the AppBar action's own
    // comment above for why this is a stub for now).
    // TODO: 配車マッチングが実装されたら、マッチしたrideの乗車地点座標で
    // ここから launchWazeNavigation() を呼ぶ（現状スタブである理由は
    // core/navigation/waze_launcher.dart とAppBarアクション側のコメント
    // 参照）。
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.driverNavigateWithWazeStubMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitleDriver),
        actions: [
          // Stubbed: there's no assigned ride/pickup coordinate to
          // navigate to yet, since ride matching isn't implemented (see
          // CLAUDE.md). The button stays visible — tapping it explains
          // why via _showWazeStub, rather than being silently disabled —
          // so drivers can see where this will live once matching exists.
          // スタブ: 配車マッチングが未実装のため（CLAUDE.md参照）、
          // ナビ対象となる乗車地点の座標がまだ無い。ボタンは表示したまま
          // にし、タップすると_showWazeStubで理由を説明する
          // （黙って無効化するのではなく）— マッチング実装後にここへ
          // 機能が入ることをドライバーに示すため。
          IconButton(
            onPressed: _showWazeStub,
            tooltip: l10n.driverNavigateWithWazeTooltip,
            icon: const Icon(Icons.navigation_outlined),
          ),
          const LanguageSwitcherButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logoutTooltip,
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: _isOnline
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _isOnline ? Icons.circle : Icons.circle_outlined,
                  color: _isOnline ? Colors.green : Colors.grey,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  _isOnline ? l10n.driverOnlineStatus : l10n.driverOfflineStatus,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: _isOnline,
                  onChanged: (value) {
                    setState(() => _isOnline = value);
                    // TODO: Once Supabase is connected, start/stop
                    // streaming this driver's location to Realtime here.
                    // TODO: Supabase接続後、ここでこのドライバーの位置情報を
                    // Realtimeへ配信開始／停止する。
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.motorcycle,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOnline
                        ? l10n.driverWaitingForRequests
                        : l10n.driverGoOnlineToReceiveRequests,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
