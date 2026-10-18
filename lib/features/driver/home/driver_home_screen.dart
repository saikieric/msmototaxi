import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/locale/language_switcher_button.dart';
import '../../../core/location/driver_location_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

/// How often an online driver's GPS position is UPSERTed into
/// `driver_locations` — frequent enough for passengers to see a reasonably
/// fresh position on the map, without hammering the DB/battery with every
/// GPS reading.
/// オンライン中のドライバーのGPS位置を`driver_locations`へUPSERTする頻度 —
/// 乗客が地図上でそれなりに新しい位置を見られる程度に短く、かつGPS取得の
/// たびにDB/バッテリーを叩かない程度に長い間隔。
const _locationPingInterval = Duration(seconds: 10);

/// Driver home screen.
/// ドライバー用ホーム画面。
///
/// Placeholder for the incoming-ride-request UI. The online/offline toggle
/// is wired up: going online starts periodically UPSERTing this driver's
/// GPS position into `driver_locations` (see
/// `core/location/driver_location_repository.dart`), picked up by
/// Realtime for passengers' "nearby drivers" map (per slides.md
/// "位置情報・地理検索"); going offline (or leaving this screen) stops it.
/// `driver_id` is `auth.uid()` from [AuthRepository.signInAnonymously].
/// Subscribing to incoming match offers from the matching Edge Function is
/// still a placeholder.
/// 配車依頼受信UIのプレースホルダー。オンライン／オフライン切り替えは
/// 実装済み: オンラインにするとこのドライバーのGPS位置情報を定期的に
/// `driver_locations`へUPSERTし始め（`core/location/driver_location_repository.dart`
/// 参照）、Realtime経由で乗客側の「近くのドライバー」地図に反映される
/// （slides.md「位置情報・地理検索」参照）。オフラインにする（または
/// この画面を離れる）と停止する。`driver_id` は
/// [AuthRepository.signInAnonymously] の `auth.uid()`。マッチング用
/// Edge Functionからの依頼のsubscribeはまだプレースホルダーのまま。
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _isOnline = false;
  Timer? _locationTimer;

  Future<void> _signOut() => AuthRepository.instance.signOut();

  /// Turns the online toggle on: checks location access up front (so a
  /// denial shows an explanation instead of the switch silently doing
  /// nothing) and, once granted, starts [_locationTimer] pinging
  /// immediately and then every [_locationPingInterval].
  /// オンライン切り替えをオンにする: まず位置情報アクセスを確認し
  /// （拒否された場合にスイッチが無言で何もしないのではなく、理由を
  /// 表示するため）、許可されたら即座に1回pingしてから
  /// [_locationPingInterval] ごとに送信する[_locationTimer]を開始する。
  Future<void> _goOnline() async {
    final l10n = AppLocalizations.of(context)!;

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.driverLocationServiceDisabledMessage)),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.driverLocationPermissionDeniedMessage)),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isOnline = true);
    unawaited(_sendLocationPing());
    _locationTimer = Timer.periodic(
      _locationPingInterval,
      (_) => _sendLocationPing(),
    );
  }

  /// Turns the online toggle off and stops [_locationTimer]. Also called
  /// from [dispose] so a driver who navigates away (e.g. signs out) while
  /// online doesn't keep pinging in the background.
  /// オンライン切り替えをオフにし、[_locationTimer]を停止する。
  /// [dispose]からも呼ばれる — オンラインのままこの画面を離れる
  /// （例: ログアウト）場合でも、バックグラウンドでpingを続けないように。
  void _goOffline() {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (!mounted) return;
    setState(() => _isOnline = false);
  }

  /// Fetches the current GPS fix and UPSERTs it via
  /// [DriverLocationRepository]. Failures (e.g. a transient GPS or network
  /// error) are swallowed rather than shown to the driver — the next timer
  /// tick retries on its own, and the up-front checks in [_goOnline]
  /// already covered the "no permission at all" case.
  /// 現在のGPS位置を取得し、[DriverLocationRepository]経由でUPSERTする。
  /// 失敗（一時的なGPS/通信エラー等）はドライバーに表示せず無視する —
  /// 次のタイマー実行で自動的に再試行されるし、「権限が全く無い」ケースは
  /// [_goOnline]の事前チェックで既に対処済み。
  Future<void> _sendLocationPing() async {
    final driverId = AuthRepository.instance.currentUser?.id;
    if (driverId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition();
      await DriverLocationRepository.instance.upsert(
        driverId: driverId,
        position: position,
      );
    } catch (_) {
      // Swallowed — see doc comment above.
      // 無視する — 上のdocコメント参照。
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
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
                  // "Online" uses the theme's secondary (tea green — see
                  // core/theme/motogo_theme.dart), matching the pickup
                  // marker/pill on the passenger side rather than a
                  // generic Material green.
                  // 「オンライン」はテーマのsecondary（茶の緑 —
                  // core/theme/motogo_theme.dart参照）を使う。汎用的な
                  // Material緑ではなく、乗客側の乗車地点マーカー/ピルと
                  // 揃える。
                  color: _isOnline
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.outline,
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
                    if (value) {
                      unawaited(_goOnline());
                    } else {
                      _goOffline();
                    }
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
