import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/dev_auth_bypass.dart';
import '../../../core/locale/language_switcher_button.dart';
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

/// Passenger home screen: a map to request a ride on.
/// 乗客用ホーム画面: 配車依頼を出すための地図。
///
/// Flow: pickup defaults to the device's current location (draggable);
/// tapping the map sets the dropoff point. The request button is enabled
/// once both are set.
///
/// Actually creating the ride (writing to Supabase `rides`) is still a stub
/// — it needs a real signed-in user (RLS requires auth.uid() = passenger_id)
/// and the matching Edge Function, neither of which exist yet. See
/// dev_auth_bypass.dart for why login is currently skippable.
///
/// フロー: 乗車地点はデフォルトで現在地（ドラッグ可能）。地図をタップすると
/// 降車地点を設定。両方設定されると依頼ボタンが有効になる。
///
/// 実際の配車依頼作成（Supabaseの`rides`への書き込み）はまだスタブ。
/// RLSが auth.uid() = passenger_id を要求するため実際のログインユーザーが
/// 必要で、マッチング用Edge Functionもまだ無い。ログインを省略できる理由は
/// dev_auth_bypass.dart 参照。
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

  Future<void> _signOut() async {
    await AuthRepository.instance.signOut();
    ref.read(devAuthBypassProvider.notifier).state = false;
  }

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
    final markers = <Marker>{
      if (_pickupLocation != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          draggable: true,
          onDragEnd: _onPickupMarkerDragEnd,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: l10n.passengerPickupMarkerTitle),
        ),
      if (_dropoffLocation != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _registroCityCenter,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Covers the case where the device's GPS fix resolves before
              // the map finishes initializing (observed in headless/mocked
              // geolocation testing, but possible on a slow device too) —
              // without this, _zoomToPickup's earlier call from
              // _initPickupFromDeviceLocation silently no-ops on a
              // still-null controller and the map is left at the initial
              // city-wide view.
              // GPS取得地点の解決が地図の初期化完了より先に終わるケースに
              // 対応する（ヘッドレス/モック位置情報でのテストで確認済みだが、
              // 低速な端末でも起こりうる）— これが無いと、
              // _initPickupFromDeviceLocationからの_zoomToPickup呼び出しが
              // まだnullなコントローラに対して無言でno-opになり、地図が
              // 初期の街全体ビューのまま残ってしまう。
              _zoomToPickup();
            },
            onTap: _onMapTap,
            markers: markers,
            // Visualizes _pickupRadiusMeters around the device's actual GPS
            // fix, so the drag constraint in _clampToPickupRadius is
            // something the user can see, not just silently enforced.
            // _pickupRadiusMetersを端末の実際のGPS取得地点の周りに可視化する。
            // _clampToPickupRadiusでのドラッグ制約を、暗黙に強制するのではなく
            // ユーザーが目で見て分かるようにする。
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
          Positioned(
            right: 16,
            bottom: 180,
            child: FloatingActionButton.small(
              onPressed: _pickupLocation == null
                  ? null
                  : () => _mapController?.animateCamera(
                      CameraUpdate.newLatLng(_pickupLocation!),
                    ),
              tooltip: l10n.passengerBackToPickupTooltip,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RideStatusLine(
                      icon: Icons.circle,
                      color: Colors.green,
                      label: _pickupLocation == null
                          ? l10n.passengerPickupNotSet
                          : l10n.passengerPickupSet,
                    ),
                    if (_deviceLocation != null) ...[
                      const SizedBox(height: 2),
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
                    ],
                    const SizedBox(height: 4),
                    _RideStatusLine(
                      icon: Icons.location_on,
                      color: Colors.red,
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
