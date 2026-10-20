import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/locale/language_switcher_button.dart';
import '../../../core/location/driver_location_repository.dart';
import '../../../core/location/registro_city_center.dart';
import '../../../l10n/generated/app_localizations.dart';

/// How often an online driver's GPS position is UPSERTed into
/// `driver_locations` — frequent enough for passengers to see a reasonably
/// fresh position on the map, without hammering the DB/battery with every
/// GPS reading.
/// オンライン中のドライバーのGPS位置を`driver_locations`へUPSERTする頻度 —
/// 乗客が地図上でそれなりに新しい位置を見られる程度に短く、かつGPS取得の
/// たびにDB/バッテリーを叩かない程度に長い間隔。
const _locationPingInterval = Duration(seconds: 10);

/// Zoom level the camera settles on once the driver's own location is
/// known — close enough to feel like "my location" rather than the
/// initial city-wide view (14), without the tight framing
/// `passenger_home_screen.dart` uses for its draggable pickup-radius pin
/// (this screen has no equivalent radius to show).
/// ドライバー自身の位置が判明した時点でカメラが収まるズームレベル。
/// 初期の街全体ビュー（14）ではなく「自分の位置」らしく寄せるが、
/// `passenger_home_screen.dart`がドラッグ可能な乗車地点調整円のために
/// 使う寄りの強いズームほどではない（この画面には対応する調整円が無い）。
const _driverLocationZoom = 16.0;

/// Renders a filled circle in [color], for the device-location marker —
/// same shape/rationale as `passenger_home_screen.dart`'s
/// `_createDotBitmap` (duplicated here rather than shared, since both are
/// tiny and private to their own screen): a plain "you are here" dot,
/// distinguishable from a generic default marker, that also sidesteps
/// Flutter Web's `BitmapDescriptor.defaultMarkerWithHue` bug
/// (flutter/flutter#87917, #161948) where the hue is ignored and the pin
/// always renders red.
/// [color]で塗りつぶした単純な円を描画する。現在地マーカー用 —
/// `passenger_home_screen.dart`の`_createDotBitmap`と同じ形・同じ理由
/// （どちらも小さく各画面に private なため、共有せずここでも複製）:
/// 汎用的なデフォルトマーカーと区別できる単純な「現在地」ドット。
/// Flutter Webの`BitmapDescriptor.defaultMarkerWithHue`のバグ
/// （flutter/flutter#87917、#161948。hueが無視され常に赤で描画される）も
/// これにより回避できる。
Future<BitmapDescriptor> _createDotBitmap(Color color) async {
  const size = 64.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
  const center = Offset(size / 2, size / 2);
  const radius = size / 2 - 4;

  canvas.drawCircle(center, radius, Paint()..color = color);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4,
  );

  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

/// Driver home screen: a full-screen map centered on the driver, with the
/// online/offline status strip and the waiting-for-requests message
/// floating on top of it.
/// ドライバー用ホーム画面: ドライバー自身を中心にした全画面地図の上に、
/// オンライン/オフラインのステータス帯と、依頼待ちメッセージを重ねて表示。
///
/// The online/offline toggle is wired up: going online starts periodically
/// UPSERTing this driver's GPS position into `driver_locations` (see
/// `core/location/driver_location_repository.dart`), picked up by
/// Realtime for passengers' "nearby drivers" map (per slides.md
/// "位置情報・地理検索"); going offline (or leaving this screen) stops it.
/// `driver_id` is `auth.uid()` from [AuthRepository.signInAnonymously].
/// The map's own device-location marker/camera (see [_driverLocation]) is
/// independent of this toggle — it's shown whenever location access is
/// available, online or not, same as `passenger_home_screen.dart`'s
/// always-on device-location marker. Subscribing to incoming match offers
/// from the matching Edge Function is still a placeholder.
/// オンライン／オフライン切り替えは実装済み: オンラインにするとこの
/// ドライバーのGPS位置情報を定期的に`driver_locations`へUPSERTし始め
/// （`core/location/driver_location_repository.dart`参照）、Realtime経由で
/// 乗客側の「近くのドライバー」地図に反映される（slides.md
/// 「位置情報・地理検索」参照）。オフラインにする（またはこの画面を離れる）
/// と停止する。`driver_id` は[AuthRepository.signInAnonymously]の
/// `auth.uid()`。地図自体の現在地マーカー/カメラ（[_driverLocation]参照）は
/// この切り替えとは独立していて、オンライン・オフラインどちらでも位置情報
/// アクセスが得られていれば表示される —
/// `passenger_home_screen.dart`の常時表示の現在地マーカーと同様。
/// マッチング用Edge Functionからの依頼のsubscribeはまだプレースホルダーの
/// まま。
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _isOnline = false;
  Timer? _locationTimer;

  /// Tracks the driver's *latest* toggle intent, independent of how far
  /// [_goOnline]'s permission checks have progressed. Needed because a
  /// quick on→off tap can resolve _goOffline while _goOnline is still
  /// awaiting a permission prompt; without this, _goOnline would resume
  /// and start the timer even though the driver already asked to go
  /// offline.
  /// ドライバーの*最新の*切り替え意図を、[_goOnline]の権限チェックが
  /// どこまで進んでいるかとは独立に追跡する。オン→オフを素早くタップすると
  /// _goOnlineが権限プロンプトのawait中に_goOfflineが先に解決してしまう
  /// 場合があるため必要 — これが無いと、ドライバーが既にオフラインを
  /// 要求した後でも_goOnlineが再開してタイマーを開始してしまう。
  bool _wantsOnline = false;

  GoogleMapController? _mapController;
  // The device's actual GPS fix, for the background map's own marker and
  // initial camera centering — populated once on screen load (see
  // _initDeviceLocationForMap) and refreshed opportunistically from each
  // online location ping (see _sendLocationPing) so the dot tracks the
  // driver while online, without issuing any extra GPS reads of its own.
  // Null if a fix was never obtained (permission/service denied); the map
  // then just stays at the Registro default, same as the fallback in
  // passenger_home_screen.dart.
  // 端末の実際のGPS取得地点。背景地図自身のマーカーと初期カメラ位置に使う —
  // 画面表示時に一度だけ取得し（_initDeviceLocationForMap参照）、以後は
  // オンライン中の位置ping（_sendLocationPing参照）から便乗で更新する
  // ため、そのための追加のGPS取得は発生しない。一度も取得できなかった場合
  // （権限/サービス拒否）はnullのままで、地図はRegistroのデフォルト位置に
  // 留まる — passenger_home_screen.dartのフォールバックと同様。
  LatLng? _driverLocation;
  // Custom-drawn dot bitmap — see _createDotBitmap for why this replaces
  // GoogleMap's myLocationEnabled flag. Null until the async draw
  // finishes (briefly, at startup); the marker falls back to the plain
  // default marker until then.
  // 自前で描画したドット画像 — GoogleMapの`myLocationEnabled`フラグの
  // 代わりにこれを使う理由は_createDotBitmap参照。非同期の描画が完了する
  // （起動時のごく短い間）まではnullで、それまでマーカーは通常のデフォルト
  // マーカーにフォールバックする。
  BitmapDescriptor? _deviceLocationIcon;

  Future<void> _signOut() => AuthRepository.instance.signOut();

  @override
  void initState() {
    super.initState();
    _initDeviceLocationForMap();
    _loadMarkerIcon();
  }

  Future<void> _loadMarkerIcon() async {
    // Plain blue, same as passenger_home_screen.dart's device-location
    // dot — the universal "this is your live GPS position" convention
    // from native maps apps, kept consistent across both flavors.
    // プレーンな青色。passenger_home_screen.dartの現在地ドットと同じ —
    // あらゆるネイティブ地図アプリ共通の「これが自分の現在地」という
    // 慣習色を、両flavorで一致させる。
    final icon = await _createDotBitmap(Colors.blue);
    if (!mounted) return;
    setState(() => _deviceLocationIcon = icon);
  }

  /// Animates the camera to [_driverLocation] once both it and the map
  /// controller are ready — no-ops otherwise. Called from both the
  /// geolocation success path and `onMapCreated`, since either can
  /// resolve first (same reasoning as
  /// `passenger_home_screen.dart`'s `_zoomToPickup`).
  /// [_driverLocation] にカメラを移動する。それとマップコントローラの
  /// 両方が準備できている場合のみ動作する。位置情報取得成功時と
  /// `onMapCreated` の両方から呼ばれる — どちらが先に解決するかは
  /// 状況次第のため（`passenger_home_screen.dart`の`_zoomToPickup`と同じ
  /// 理由）。
  void _zoomToDriverLocation() {
    final location = _driverLocation;
    if (location == null) return;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(location, _driverLocationZoom),
    );
  }

  /// One-time fetch of the device's current GPS fix purely for the
  /// background map's marker/camera — independent of the online/offline
  /// toggle below, so it runs regardless of [_isOnline]. Failures
  /// (permission/service denied, or any other error) are swallowed, same
  /// as [_sendLocationPing]: the map simply stays at the Registro default
  /// rather than showing an error banner, since the driver already gets
  /// an explicit permission prompt/snackbar when they try to go online.
  /// 背景地図のマーカー/カメラのためだけに、端末の現在のGPS位置を一度だけ
  /// 取得する — 下のオンライン/オフライン切り替えとは独立しているため、
  /// [_isOnline]に関わらず実行される。失敗（権限/サービス拒否、その他の
  /// エラー）は[_sendLocationPing]と同様に無視する: エラーバナーは出さず
  /// 地図はRegistroのデフォルト位置のままになる — オンラインにしようと
  /// した時点で、権限プロンプト/スナックバーは別途表示されるため。
  Future<void> _initDeviceLocationForMap() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _driverLocation = LatLng(position.latitude, position.longitude);
      });
      _zoomToDriverLocation();
    } catch (_) {
      // Swallowed — see doc comment above.
      // 無視する — 上のdocコメント参照。
    }
  }

  /// Turns the online toggle on: checks location access up front (so a
  /// denial shows an explanation instead of the switch silently doing
  /// nothing) and, once granted, starts [_locationTimer] pinging
  /// immediately and then every [_locationPingInterval]. Bails out
  /// without starting anything if the driver toggled back offline
  /// ([_wantsOnline] went false) while these checks were in flight.
  /// オンライン切り替えをオンにする: まず位置情報アクセスを確認し
  /// （拒否された場合にスイッチが無言で何もしないのではなく、理由を
  /// 表示するため）、許可されたら即座に1回pingしてから
  /// [_locationPingInterval] ごとに送信する[_locationTimer]を開始する。
  /// このチェックの最中にドライバーがオフラインへ戻した
  /// （[_wantsOnline]がfalseになった）場合は、何も開始せずに中断する。
  Future<void> _goOnline() async {
    _wantsOnline = true;
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

    if (!mounted || !_wantsOnline) return;
    setState(() => _isOnline = true);
    unawaited(_sendLocationPing());
    _locationTimer = Timer.periodic(
      _locationPingInterval,
      (_) => _sendLocationPing(),
    );
  }

  /// Turns the online toggle off and stops [_locationTimer]. Also called
  /// from [dispose] so a driver who navigates away (e.g. signs out) while
  /// online doesn't keep pinging in the background. Clearing
  /// [_wantsOnline] here is what stops an in-flight [_goOnline] (still
  /// awaiting its permission checks) from starting the timer afterwards.
  /// オンライン切り替えをオフにし、[_locationTimer]を停止する。
  /// [dispose]からも呼ばれる — オンラインのままこの画面を離れる
  /// （例: ログアウト）場合でも、バックグラウンドでpingを続けないように。
  /// ここで[_wantsOnline]をクリアすることで、実行中の（権限チェックを
  /// await中の）[_goOnline]が後からタイマーを開始してしまうのを防ぐ。
  void _goOffline() {
    _wantsOnline = false;
    _locationTimer?.cancel();
    _locationTimer = null;
    if (!mounted) return;
    setState(() => _isOnline = false);
  }

  /// Fetches the current GPS fix and UPSERTs it via
  /// [DriverLocationRepository]. Also feeds [_driverLocation] from the
  /// same fix (no extra GPS read) so the background map's marker tracks
  /// the driver while online — it deliberately does NOT re-animate the
  /// camera on every tick (unlike the one-time
  /// [_initDeviceLocationForMap]/[_zoomToDriverLocation] pair), so a
  /// driver who's panned the map away isn't yanked back every
  /// [_locationPingInterval]. Failures (e.g. a transient GPS or network
  /// error) are swallowed rather than shown to the driver — the next
  /// timer tick retries on its own, and the up-front checks in
  /// [_goOnline] already covered the "no permission at all" case.
  /// 現在のGPS位置を取得し、[DriverLocationRepository]経由でUPSERTする。
  /// 同じ取得結果から[_driverLocation]も更新する（追加のGPS取得は発生
  /// しない）ため、オンライン中は背景地図のマーカーがドライバーを追従
  /// する — ただし毎回カメラを再アニメーションすることは意図的にしない
  /// （一度だけの[_initDeviceLocationForMap]/[_zoomToDriverLocation]とは
  /// 違う）。これにより、地図を別の場所にパンしたドライバーが
  /// [_locationPingInterval]ごとに引き戻されることはない。失敗
  /// （一時的なGPS/通信エラー等）はドライバーに表示せず無視する —
  /// 次のタイマー実行で自動的に再試行されるし、「権限が全く無い」ケースは
  /// [_goOnline]の事前チェックで既に対処済み。
  Future<void> _sendLocationPing() async {
    final driverId = AuthRepository.instance.currentUser?.id;
    if (driverId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _driverLocation = LatLng(position.latitude, position.longitude);
        });
      }
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
    _mapController?.dispose();
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
      // Unlike passenger_home_screen.dart, the status strip (with its
      // online/offline Switch) is deliberately stacked ON TOP of the map
      // instead of living in a separate, non-overlapping section below
      // it. passenger_home_screen.dart avoids that because, in this
      // environment, a tap on a widget stacked over GoogleMap on web can
      // also land on the map underneath (flutter/flutter#118159 covers
      // known instability in the GoogleMap + Stack combination) — risky
      // there because a leaked tap sets the dropoff point. This map has
      // no `onTap` handler at all, so the same leaked tap here is simply
      // a no-op: there's nothing for it to corrupt, so the overlap this
      // screen was asked for is safe to do directly.
      // passenger_home_screen.dartとは異なり、このステータス帯
      // （オンライン/オフラインのSwitch付き）はあえて地図の「上」に
      // Stackで重ねている（地図と重ならない別セクションに分離していない）。
      // passenger_home_screen.dartがそうしているのは、この環境ではWeb版の
      // GoogleMapに重ねたウィジェットへのタップが、同時に下の地図にも
      // 届いてしまうことがあるため（flutter/flutter#118159がGoogleMap +
      // Stackの組み合わせに既知の不安定さがあることを裏付けている）—
      // そちらではタップが漏れると降車地点が設定されてしまうため危険
      // だった。この地図には`onTap`ハンドラ自体が無いため、同様にタップが
      // 漏れても単なる無害な空振りになる — 壊すものが何も無いため、
      // この画面で求められている重ね合わせはそのまま行って問題ない。
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: registroCityCenter,
                zoom: 14,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                // Covers the case where the device's GPS fix resolves
                // before the map finishes initializing — same race as
                // passenger_home_screen.dart's onMapCreated handles for
                // _zoomToPickup.
                // GPS取得地点の解決が地図の初期化完了より先に終わるケースに
                // 対応する — passenger_home_screen.dartのonMapCreatedが
                // _zoomToPickupのために対処しているのと同じ競合状態。
                _zoomToDriverLocation();
              },
              markers: _driverLocation == null
                  ? const {}
                  : {
                      Marker(
                        markerId: const MarkerId('device_location'),
                        position: _driverLocation!,
                        icon:
                            _deviceLocationIcon ??
                            BitmapDescriptor.defaultMarker,
                        // The dot bitmap is a plain circle (no pointed
                        // tip), so it anchors at its exact center — see
                        // passenger_home_screen.dart's equivalent anchor
                        // comment for the full reasoning.
                        // ドット画像は（先端の無い）単純な円のため、その
                        // 中心を基準にする — 詳しい理由は
                        // passenger_home_screen.dartの同等のアンカー関連
                        // コメント参照。
                        anchor: const Offset(0.5, 0.5),
                        zIndexInt: 0,
                      ),
                    },
              // Intentionally NOT using myLocationEnabled — verified in
              // this environment that google_maps_flutter_web doesn't
              // actually render it (same finding as
              // passenger_home_screen.dart). The device_location marker
              // above is this screen's own reliable, cross-platform
              // equivalent.
              // あえてmyLocationEnabledは使っていない — この環境で検証した
              // 結果、google_maps_flutter_webでは実際には描画されない
              // ことを確認済み（passenger_home_screen.dartと同じ知見）。
              // 上のdevice_locationマーカーが、これに代わる自前実装の
              // クロスプラットフォームで確実に動く同等機能。
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
          Positioned.fill(
            child: Column(
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
                        // "Online" uses the theme's secondary (tea green
                        // — see core/theme/motogo_theme.dart), matching
                        // the pickup marker/pill on the passenger side
                        // rather than a generic Material green.
                        // 「オンライン」はテーマのsecondary（茶の緑 —
                        // core/theme/motogo_theme.dart参照）を使う。
                        // 汎用的なMaterial緑ではなく、乗客側の乗車地点
                        // マーカー/ピルと揃える。
                        color: _isOnline
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.outline,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isOnline
                            ? l10n.driverOnlineStatus
                            : l10n.driverOfflineStatus,
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
                // The waiting-for-requests message, now a floating card
                // over the map rather than a plain Center on an opaque
                // background — the Expanded above leaves the rest of
                // this Column transparent, so the map shows through
                // around the card.
                // 依頼待ちメッセージ。単色背景の上のCenterではなく、地図に
                // 浮かぶカードにした — 上のExpandedがこのColumnの残り部分を
                // 透明にしているため、カードの周囲に地図が透けて見える。
                Expanded(
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
