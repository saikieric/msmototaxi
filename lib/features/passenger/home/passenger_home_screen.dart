import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/locale/language_switcher_button.dart';
import '../../../core/theme/motogo_theme.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Registro, SP city center — used as the default map camera position
/// before the device's actual location is available (or if it's denied).
/// Registro市（サンパウロ州）中心部の座標。実際の現在地が取得できるまで
/// （または権限が拒否された場合）の初期カメラ位置に使う。
const _registroCityCenter = LatLng(-24.4950, -47.8433);

/// How far the pickup pin can be adjusted from the device's actual GPS fix.
/// Drawn on the map as a circle (see `build()`'s `circles:`) so the limit is
/// visible, not just enforced silently.
/// 乗車地点のピンを、端末の実際のGPS取得地点からどれだけ調整できるか。
/// 地図上に円として描画し（`build()`の`circles:`参照）、制限を暗黙のもの
/// にせず可視化する。
const _pickupRadiusMeters = 50.0;

const _earthRadiusMeters = 6371000.0;

/// Returns the point [distanceMeters] from [origin] along compass bearing
/// [bearingDegrees], via the standard spherical-earth "destination point
/// given distance and bearing" formula. Used to clamp a dragged pickup pin
/// back onto the edge of the pickup-radius circle — see
/// `_PassengerHomeScreenState._clampToPickupRadius`.
/// [origin] から方位角 [bearingDegrees]（コンパス方位）へ [distanceMeters]
/// 進んだ地点を、球面地球モデルの標準的な「距離と方位から目的地を求める」
/// 公式で返す。ドラッグされた乗車地点ピンを、乗車地点調整円の円周上まで
/// 引き戻すために使う —
/// `_PassengerHomeScreenState._clampToPickupRadius` 参照。
LatLng _destinationPoint(
  LatLng origin, {
  required double bearingDegrees,
  required double distanceMeters,
}) {
  final bearing = bearingDegrees * math.pi / 180;
  final lat1 = origin.latitude * math.pi / 180;
  final lon1 = origin.longitude * math.pi / 180;
  final angularDistance = distanceMeters / _earthRadiusMeters;

  final lat2 = math.asin(
    math.sin(lat1) * math.cos(angularDistance) +
        math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
  );
  final lon2 =
      lon1 +
      math.atan2(
        math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
        math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
      );

  return LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
}

// Shared reasoning for why both drawing functions below exist instead of
// BitmapDescriptor.defaultMarkerWithHue: Flutter Web's Google Maps
// implementation has a long-standing, unresolved bug where it ignores the
// hue and always renders the standard red pin (flutter/flutter#87917,
// #161948) — with only that, the pickup (meant to be green) and dropoff
// (red) markers were indistinguishable on web. Drawing our own bitmaps
// sidesteps the bug entirely and looks the same on every platform.
// 下の2つの描画関数が、`BitmapDescriptor.defaultMarkerWithHue`の代わりに
// 存在する共通の理由: Flutter WebのGoogle Maps実装にはhueを無視して常に
// 標準の赤いピンを描画するという長年未解決のバグがある
// （flutter/flutter#87917、#161948）— これだけだと、乗車地点（本来は緑）と
// 降車地点（赤）のマーカーがWeb上で区別できなくなってしまう。自前で
// ビットマップを描画することでこのバグを完全に回避でき、かつどの
// プラットフォームでも同じ見た目になる。

/// Renders a filled circle in [color], for the device-location marker — a
/// plain dot, matching the "you are here" convention from native maps
/// apps (see the `device_location` marker's own doc comment), as opposed
/// to the teardrop pin shape [_createPinBitmap] draws for pickup/dropoff.
/// [color] で塗りつぶした単純な円を描画する。現在地マーカー用 —
/// ネイティブ地図アプリ共通の「現在地」慣習（`device_location`マーカー
/// 自体のdocコメント参照）に合わせた単純なドット。乗車/降車地点用に
/// [_createPinBitmap] が描く涙形ピンとは対照的な形。
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

const _pinWidth = 56.0;
const _pinHeight = 76.0;
const _pinHeadRadius = 17.0;
const _pinPad = 4.0;

/// Fraction down [_pinHeight] where the pin's tip sits — the exact point
/// that marks the geographic coordinate. Passed as the [Marker.anchor] for
/// pickup/dropoff so the tip, not the bitmap's center, lands on the
/// coordinate (see `_PassengerHomeScreenState.build`'s anchor comment for
/// why this matters — a plain circle bitmap needed anchor (0.5, 0.5)
/// instead; a pin shape's marked point is its tip, so it needs (0.5, 1.0)
/// in this coordinate system's proportions).
/// [_pinHeight]のうち、ピンの先端がある位置の割合。地理座標を実際に指す点。
/// 乗車/降車地点の[Marker.anchor]としてこれを渡し、画像の中心ではなく先端が
/// 座標に来るようにする（なぜこれが重要かは
/// `_PassengerHomeScreenState.build`のアンカー関連コメント参照 — 単純な円の
/// 画像は代わりにアンカー(0.5, 0.5)が必要だった。ピン形状が指す点は先端
/// なので、この座標系の比率では(0.5, 1.0)が必要）。
const pinTipAnchorFraction = (_pinHeight - _pinPad) / _pinHeight;

/// Renders a classic teardrop map-pin silhouette (a round head over a
/// tapered tail meeting at a point) filled with [color], for the
/// pickup/dropoff markers. See [pinTipAnchorFraction] for how callers must
/// anchor it, and the comment block above [_createDotBitmap] for why this
/// is hand-drawn instead of using a built-in pin.
/// 涙形の地図ピン（丸い頭部と、一点に収束する先細りの尾）を[color]で
/// 塗りつぶして描画する。乗車/降車地点マーカー用。呼び出し側でどう
/// アンカーする必要があるかは[pinTipAnchorFraction]参照。なぜ組み込みの
/// ピンを使わず自前で描画するかは[_createDotBitmap]直前のコメント参照。
Future<BitmapDescriptor> _createPinBitmap(Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    const Rect.fromLTWH(0, 0, _pinWidth, _pinHeight),
  );
  const cx = _pinWidth / 2;
  const cy = _pinPad + _pinHeadRadius;
  const tipY = _pinHeight - _pinPad;
  const tailHalfWidth = _pinHeadRadius * 0.55;

  final head = Path()
    ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: _pinHeadRadius));
  final tail = Path()
    ..moveTo(cx - tailHalfWidth, cy)
    ..lineTo(cx + tailHalfWidth, cy)
    ..lineTo(cx, tipY)
    ..close();
  final pin = Path.combine(PathOperation.union, head, tail);

  canvas.drawPath(pin, Paint()..color = color);
  canvas.drawPath(
    pin,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );

  final image = await recorder.endRecording().toImage(
    _pinWidth.toInt(),
    _pinHeight.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

/// Passenger home screen: a map to request a ride on.
/// 乗客用ホーム画面: 配車依頼を出すための地図。
///
/// Flow: pickup defaults to the device's current location (draggable);
/// tapping the map sets the dropoff point. The request button is enabled
/// once both are set.
///
/// Actually creating the ride (writing to Supabase `rides`) is still a stub
/// — it needs the matching Edge Function, which doesn't exist yet. The
/// RLS requirement (auth.uid() = passenger_id) is already satisfied, since
/// login now creates a real anonymous Supabase session (see
/// AuthRepository.signInAnonymously).
///
/// フロー: 乗車地点はデフォルトで現在地（ドラッグ可能）。地図をタップすると
/// 降車地点を設定。両方設定されると依頼ボタンが有効になる。
///
/// 実際の配車依頼作成（Supabaseの`rides`への書き込み）はまだスタブ。
/// マッチング用Edge Functionがまだ無いため。RLSの要件
/// （auth.uid() = passenger_id）はログインが実際の匿名Supabaseセッションを
/// 作成するようになった（AuthRepository.signInAnonymously参照）ため、既に
/// 満たされている。
class PassengerHomeScreen extends ConsumerStatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  ConsumerState<PassengerHomeScreen> createState() =>
      _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends ConsumerState<PassengerHomeScreen> {
  GoogleMapController? _mapController;
  // The device's actual GPS fix, used as the center of the pickup-radius
  // circle and the reference point pickup adjustments are clamped against.
  // Null if location couldn't be obtained (permission/service denied) —
  // in that case there's no reference point, so pickup is set freely by
  // tapping instead (see _onMapTap).
  // 端末の実際のGPS取得地点。乗車地点調整円の中心、および乗車地点調整の
  // クランプ基準として使う。位置情報が取得できなかった場合（権限/サービス
  // 拒否）はnull — その場合は基準点が無いため、代わりにタップで自由に
  // 乗車地点を設定する（_onMapTap参照）。
  LatLng? _deviceLocation;
  // The adjustable pickup pin — defaults to _deviceLocation once known, but
  // can be dragged within _pickupRadiusMeters of it (see
  // _onPickupMarkerDragEnd).
  // 調整可能な乗車地点ピン。_deviceLocationが判明次第それをデフォルトにするが、
  // そこから_pickupRadiusMeters以内であればドラッグで動かせる
  // （_onPickupMarkerDragEnd参照）。
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  // Custom-drawn marker bitmaps — see _createPinBitmap for why these
  // replace BitmapDescriptor.defaultMarkerWithHue. Null until the async
  // draw finishes (briefly, at startup); markers fall back to the plain
  // default marker until then.
  // 自前で描画したマーカー画像 — なぜ`BitmapDescriptor.defaultMarkerWithHue`
  // の代わりにこれを使うかは_createPinBitmap参照。非同期の描画が完了する
  // （起動時のごく短い間）まではnullで、それまでマーカーは通常のデフォルト
  // マーカーにフォールバックする。
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  // Marks _deviceLocation itself (see below) — distinct from the pickup
  // pin, which starts at the same spot but the user can drag away from it.
  // _deviceLocation自体を示す（下記参照）— 乗車地点ピンとは別物で、
  // 最初は同じ地点だがユーザーがそこから離してドラッグできる。
  BitmapDescriptor? _deviceLocationIcon;
  bool _isLocatingDevice = true;
  // Stores which error occurred (not the localized message itself) so the
  // message can be rebuilt in the current language if it changes while the
  // banner is showing (e.g. user switches language via LanguageSwitcherButton).
  // 表示するローカライズ済みメッセージそのものではなく、発生したエラーの
  // 種類を保持する。これにより、バナー表示中に言語が切り替わっても
  // （例: LanguageSwitcherButton経由）現在の言語でメッセージを組み直せる。
  _LocationError? _locationError;

  @override
  void initState() {
    super.initState();
    _initPickupFromDeviceLocation();
    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    final icons = await Future.wait([
      // Pickup/dropoff use the brand palette (see core/theme/motogo_theme.dart)
      // instead of generic Material red/green, so the map matches the rest
      // of the app. The device-location dot deliberately stays plain blue —
      // that's the universal "this is your live GPS position" convention
      // from every native maps app, and changing it away from blue would
      // hurt recognizability for no brand benefit.
      // 乗車地点/降車地点はブランドカラー（core/theme/motogo_theme.dart参照）
      // を使い、汎用的なMaterialの赤・緑にはしない — 地図がアプリ全体の
      // 色と揃うように。現在地の点だけは意図的に青のまま —
      // あらゆるネイティブ地図アプリ共通の「これが自分の現在地」という
      // 慣習色であり、ブランド上のメリット無しにこれを変えると
      // 視認性が下がるだけのため。
      _createPinBitmap(teaAccent),
      _createPinBitmap(toriiAccent),
      _createDotBitmap(Colors.blue),
    ]);
    if (!mounted) return;
    setState(() {
      _pickupIcon = icons[0];
      _dropoffIcon = icons[1];
      _deviceLocationIcon = icons[2];
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// Animates the camera to [_pickupLocation] at a zoom close enough that
  /// the pickup-radius circle is comfortably visible/draggable, rather than
  /// the initial city-wide view (14). No-ops if either isn't ready yet —
  /// called from both the geolocation success path and `onMapCreated`,
  /// since either can resolve first (see their call sites for why).
  ///
  /// At 50m, `_pickupRadiusMeters` would render as a nearly invisible ~11px
  /// circle at zoom 15 — too small to see or to usefully drag a pin around
  /// within. 18 puts it at roughly a 90px circle, comfortably visible and
  /// draggable on a touchscreen.
  ///
  /// [_pickupLocation] にカメラを移動する。初期の街全体ビュー（14）ではなく、
  /// 乗車地点調整円が十分視認・ドラッグできるズームまで寄せる。
  /// どちらかがまだ準備できていなければ何もしない — 位置情報取得成功時と
  /// `onMapCreated` の両方から呼ばれる。どちらが先に解決するかは
  /// 状況次第のため（それぞれの呼び出し箇所のコメント参照）。
  ///
  /// 50mの場合、ズーム15では `_pickupRadiusMeters` が約11pxの円にしか
  /// ならず、視認も範囲内でのピン操作も実用的でない。18にすると約90pxの
  /// 円になり、タッチ操作でも十分視認・ドラッグできる大きさになる。
  void _zoomToPickup() {
    final pickup = _pickupLocation;
    if (pickup == null) return;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pickup, 18));
  }

  Future<void> _initPickupFromDeviceLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationError.serviceDisabled();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _LocationError.permissionDenied();
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _deviceLocation = LatLng(position.latitude, position.longitude);
        _pickupLocation = _deviceLocation;
        _isLocatingDevice = false;
      });
      _zoomToPickup();
    } on _LocationError catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e;
        _isLocatingDevice = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = _LocationError.other(e.toString());
        _isLocatingDevice = false;
      });
    }
  }

  void _onMapTap(LatLng position) {
    // No GPS fix to constrain against — let the very first tap set pickup
    // (matches the fallback banner's "地図をタップして乗車地点を選ぶことも
    // できます" promise); every tap after that sets dropoff, same as the
    // normal (device-location-known) flow below.
    // GPS取得地点が無く制約の基準が無い場合、最初のタップだけ乗車地点を
    // 設定する（フォールバックバナーの「地図をタップして乗車地点を選ぶ
    // こともできます」という案内に合わせる）。それ以降のタップは、
    // 通常（GPS取得済み）のフローと同様に降車地点を設定する。
    if (_deviceLocation == null && _pickupLocation == null) {
      setState(() => _pickupLocation = position);
      return;
    }
    setState(() => _dropoffLocation = position);
  }

  void _onPickupMarkerDragEnd(LatLng position) {
    setState(() => _pickupLocation = _clampToPickupRadius(position));
  }

  /// Clamps [candidate] to within [_pickupRadiusMeters] of [_deviceLocation]
  /// — if it's already inside, returns it unchanged; if it's outside, slides
  /// it back along the same bearing to sit exactly on the circle's edge.
  /// Returns [candidate] as-is if there's no GPS fix to clamp against.
  /// [candidate] を [_deviceLocation] から [_pickupRadiusMeters] 以内に
  /// クランプする — 既に範囲内ならそのまま返し、範囲外なら同じ方位角の
  /// まま円周上ちょうどの位置まで引き戻す。クランプの基準となるGPS取得地点が
  /// 無い場合は [candidate] をそのまま返す。
  LatLng _clampToPickupRadius(LatLng candidate) {
    final deviceLocation = _deviceLocation;
    if (deviceLocation == null) return candidate;

    final distance = Geolocator.distanceBetween(
      deviceLocation.latitude,
      deviceLocation.longitude,
      candidate.latitude,
      candidate.longitude,
    );
    if (distance <= _pickupRadiusMeters) return candidate;

    final bearing = Geolocator.bearingBetween(
      deviceLocation.latitude,
      deviceLocation.longitude,
      candidate.latitude,
      candidate.longitude,
    );
    return _destinationPoint(
      deviceLocation,
      bearingDegrees: bearing,
      distanceMeters: _pickupRadiusMeters,
    );
  }

  Future<void> _signOut() => AuthRepository.instance.signOut();

  void _requestRide() {
    final l10n = AppLocalizations.of(context)!;
    // TODO: Insert into Supabase `rides` once real auth + the matching Edge
    // Function exist (see class doc comment above).
    // TODO: 実認証とマッチング用Edge Functionが揃ったら、Supabaseの
    // `rides` へ実際に書き込む（クラスのdocコメント参照）。
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.passengerRequestRideStubMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The device-location bitmap is a plain circle (no pointed tip), so it
    // anchors at its exact center (0.5, 0.5) — the Marker default (0.5,
    // 1.0) assumes a teardrop pin whose bottom tip marks the location,
    // which would place a centerless circle floating half its own height
    // above the actual coordinate. The pickup/dropoff bitmaps ARE teardrop
    // pins now (see _createPinBitmap), so they use their own tip-relative
    // anchor instead — see pinTipAnchorFraction's doc comment.
    // 現在地の画像は（先端の無い）単純な円のため、その中心(0.5, 0.5)を
    // 基準にする — Markerのデフォルト(0.5, 1.0)は先端が地点を指す涙形ピンを
    // 想定しており、そのままだと中心の無い円が実際の座標より自分の高さの
    // 半分だけ浮いた位置に表示されてしまう。乗車/降車地点の画像は今は
    // 涙形ピンそのもの（_createPinBitmap参照）なので、代わりに先端基準の
    // 専用アンカーを使う — pinTipAnchorFractionのdocコメント参照。
    const dotAnchor = Offset(0.5, 0.5);
    const pinAnchor = Offset(0.5, pinTipAnchorFraction);

    final markers = <Marker>{
      // The device's own live position — see _deviceLocationIcon's field
      // doc comment for why this exists instead of GoogleMap's
      // myLocationEnabled. Not draggable; purely informational.
      // 端末自身のリアルタイム位置 — GoogleMapの`myLocationEnabled`の
      // 代わりにこれがある理由は_deviceLocationIconのフィールドdocコメント
      // 参照。ドラッグ不可、あくまで表示専用。
      if (_deviceLocation != null)
        Marker(
          markerId: const MarkerId('device_location'),
          position: _deviceLocation!,
          icon: _deviceLocationIcon ?? BitmapDescriptor.defaultMarker,
          anchor: dotAnchor,
          zIndexInt: 0,
        ),
      if (_pickupLocation != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          draggable: true,
          onDragEnd: _onPickupMarkerDragEnd,
          // _pickupIcon/_dropoffIcon replace defaultMarkerWithHue — see
          // _createPinBitmap for why (a Flutter Web bug makes the hue
          // param a no-op there). Falls back to the plain default marker
          // for the brief moment before the async draw finishes.
          // _pickupIcon/_dropoffIconはdefaultMarkerWithHueの代替 — 理由は
          // _createPinBitmap参照（Flutter Webのバグでhue引数が効かない）。
          // 非同期描画が完了するまでのごく短い間は、通常のデフォルト
          // マーカーにフォールバックする。
          icon: _pickupIcon ?? BitmapDescriptor.defaultMarker,
          anchor: pinAnchor,
          zIndexInt: 1,
          infoWindow: InfoWindow(title: l10n.passengerPickupMarkerTitle),
        ),
      if (_dropoffLocation != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLocation!,
          icon: _dropoffIcon ?? BitmapDescriptor.defaultMarker,
          anchor: pinAnchor,
          zIndexInt: 1,
          infoWindow: InfoWindow(title: l10n.passengerDropoffMarkerTitle),
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitlePassenger),
        actions: [
          const LanguageSwitcherButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logoutTooltip,
            onPressed: _signOut,
          ),
        ],
      ),
      // Interactive controls live in a separate, non-overlapping section
      // below the map (see the Card at the bottom of this Column) rather
      // than floating on top of it in a Stack. On web, GoogleMap renders as
      // a real HTML element (HtmlElementView); a widget merely stacked
      // visually on top of it can still leave taps reaching that element
      // underneath at the same time (confirmed here: the old "back to
      // pickup" FAB was also registering as a dropoff tap on the map below
      // it). The documented fix for this (wrapping overlays in a
      // PointerInterceptor) turned out to be unreliable in combination with
      // GoogleMap specifically — flutter/flutter#118159 confirms known
      // instability in exactly this combination (GoogleMap + Stack +
      // PointerInterceptor) — so instead of fighting that, interactive
      // controls simply don't overlap the map at all. The two _InfoBanner
      // overlays are the one remaining exception (see their own note) since
      // they aren't interactive.
      // 操作系のコントロールは、地図の上にStackで重ねるのではなく、地図の下の
      // 別セクション（このColumn末尾のCard）に分離して置く。Web版では
      // GoogleMapは実際のHTML要素（HtmlElementView）として描画されるため、
      // 視覚的に重ねるだけのウィジェットでは、タップが同時に下のHTML要素にも
      // 届いてしまうことがある（この環境で確認済み: 旧「乗車地点に戻る」FABを
      // タップすると、同時に地図側で降車地点タップとしても扱われていた）。
      // これに対する公式な対処法（オーバーレイをPointerInterceptorでラップ
      // する）は、GoogleMapとの組み合わせでは不安定であることが判明した —
      // flutter/flutter#118159が、まさにこの組み合わせ（GoogleMap + Stack +
      // PointerInterceptor）に既知の不安定さがあることを裏付けている —
      // そのため、これと戦うのではなく、操作系のコントロールを地図と一切
      // 重ねない設計にした。唯一の例外は2つの_InfoBannerオーバーレイ
      // （操作対象ではないため — 詳細は個別の注記参照）。
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _registroCityCenter,
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    // Covers the case where the device's GPS fix resolves
                    // before the map finishes initializing (observed in
                    // headless/mocked geolocation testing, but possible on
                    // a slow device too) — without this, _zoomToPickup's
                    // earlier call from _initPickupFromDeviceLocation
                    // silently no-ops on a still-null controller and the
                    // map is left at the initial city-wide view.
                    // GPS取得地点の解決が地図の初期化完了より先に終わる
                    // ケースに対応する（ヘッドレス/モック位置情報での
                    // テストで確認済みだが、低速な端末でも起こりうる）—
                    // これが無いと、_initPickupFromDeviceLocationからの
                    // _zoomToPickup呼び出しがまだnullなコントローラに対して
                    // 無言でno-opになり、地図が初期の街全体ビューのまま
                    // 残ってしまう。
                    _zoomToPickup();
                  },
                  onTap: _onMapTap,
                  markers: markers,
                  // Visualizes _pickupRadiusMeters around the device's
                  // actual GPS fix, so the drag constraint in
                  // _clampToPickupRadius is something the user can see, not
                  // just silently enforced.
                  // _pickupRadiusMetersを端末の実際のGPS取得地点の周りに
                  // 可視化する。_clampToPickupRadiusでのドラッグ制約を、
                  // 暗黙に強制するのではなくユーザーが目で見て分かるように
                  // する。
                  circles: _deviceLocation == null
                      ? const {}
                      : {
                          Circle(
                            circleId: const CircleId('pickup_radius'),
                            center: _deviceLocation!,
                            radius: _pickupRadiusMeters,
                            strokeWidth: 2,
                            strokeColor: Theme.of(context).colorScheme.primary,
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                          ),
                        },
                  // Note: intentionally NOT using GoogleMap's built-in
                  // myLocationEnabled ("blue dot") flag — verified in this
                  // environment that google_maps_flutter_web doesn't
                  // actually render it (the underlying Google Maps
                  // JavaScript API has no native "my location" primitive;
                  // that's an app-level feature on Android/iOS/Google's own
                  // web maps, not something the embeddable JS API
                  // provides). The device_location marker below (in
                  // `markers`) is our own reliable, cross-platform
                  // equivalent.
                  // 注: あえてGoogleMap組み込みのmyLocationEnabled
                  // （「青い点」）フラグは使っていない — この環境で検証した
                  // 結果、google_maps_flutter_webでは実際には描画されない
                  // ことを確認済み（Google Maps JavaScript API自体に
                  // 「現在地」を示すネイティブの仕組みが無いため。それは
                  // Android/iOS/Google自身のWeb地図が持つアプリレベルの
                  // 機能であり、組み込み用JS APIが提供するものではない）。
                  // 下の`markers`にあるdevice_locationマーカーが、これに
                  // 代わる自前実装のクロスプラットフォームで確実に動く
                  // 同等機能。
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                if (_isLocatingDevice)
                  _InfoBanner(message: l10n.passengerGettingCurrentLocation),
                if (_locationError != null)
                  _InfoBanner(
                    message:
                        '${_locationError!.localizedMessage(l10n)}\n'
                        '${l10n.passengerTapMapToPickPickupHint}',
                    isError: true,
                  ),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _RideStatusLine(
                          icon: Icons.circle,
                          color: teaAccent,
                          label: _pickupLocation == null
                              ? l10n.passengerPickupNotSet
                              : l10n.passengerPickupSet,
                        ),
                      ),
                      // Re-centers the map on the pickup point. Lives here,
                      // next to the pickup status line, rather than as a
                      // FAB floating over the map — see the class-level
                      // note above `body: Column(`.
                      // 乗車地点に地図を戻す。地図に重ねるFABとしてではなく
                      // 乗車地点ステータス行の隣にある — 理由は
                      // `body: Column(`直前のクラスレベルの注記参照。
                      IconButton(
                        onPressed: _pickupLocation == null
                            ? null
                            : () => _mapController?.animateCamera(
                                CameraUpdate.newLatLng(_pickupLocation!),
                              ),
                        tooltip: l10n.passengerBackToPickupTooltip,
                        icon: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                  if (_deviceLocation != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: Text(
                        l10n.passengerPickupRadiusHint,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  _RideStatusLine(
                    icon: Icons.location_on,
                    color: toriiAccent,
                    label: _dropoffLocation == null
                        ? l10n.passengerDropoffNotSet
                        : l10n.passengerDropoffSet,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        (_pickupLocation != null && _dropoffLocation != null)
                        ? _requestRide
                        : null,
                    icon: const Icon(Icons.motorcycle),
                    label: Text(l10n.passengerRequestRideButton),
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

class _RideStatusLine extends StatelessWidget {
  const _RideStatusLine({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Still overlaps the map (unlike the other controls — see the
    // class-level note in PassengerHomeScreen) since it's read-only, not
    // interactive: a stray tap landing on the map underneath while the user
    // is just reading it is a minor, acceptable side effect, not a broken
    // control.
    // 他のコントロールとは違い（理由はPassengerHomeScreenのクラスレベルの
    // 注記参照）、これは操作対象ではなく読み取り専用のため、依然として
    // 地図に重ねている — 読んでいるだけの間に下の地図へタップが漏れても、
    // 軽微で許容できる副作用であり、操作不能になるわけではない。
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        color: isError ? colorScheme.errorContainer : colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            style: TextStyle(
              color: isError ? colorScheme.onErrorContainer : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Which location failure occurred, kept as data (not a pre-built message)
/// so it can be localized lazily in `build()` — see the field doc comment
/// on `_PassengerHomeScreenState._locationError`.
/// どの位置情報エラーが発生したかをデータとして保持する（構築済みの
/// メッセージ文字列としてではなく）。これにより `build()` 内で遅延的に
/// ローカライズできる —
/// `_PassengerHomeScreenState._locationError` のdocコメント参照。
sealed class _LocationError {
  const _LocationError();

  const factory _LocationError.serviceDisabled() = _ServiceDisabled;
  const factory _LocationError.permissionDenied() = _PermissionDenied;
  const factory _LocationError.other(String detail) = _Other;

  String localizedMessage(AppLocalizations l10n) => switch (this) {
    _ServiceDisabled() => l10n.passengerLocationServiceDisabled,
    _PermissionDenied() => l10n.passengerLocationPermissionDenied,
    _Other(:final detail) => l10n.passengerLocationFetchFailed(detail),
  };
}

class _ServiceDisabled extends _LocationError {
  const _ServiceDisabled();
}

class _PermissionDenied extends _LocationError {
  const _PermissionDenied();
}

class _Other extends _LocationError {
  const _Other(this.detail);
  final String detail;
}
