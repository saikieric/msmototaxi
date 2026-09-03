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
        _pickupLocation = LatLng(position.latitude, position.longitude);
        _isLocatingDevice = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_pickupLocation!, 15),
      );
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
    setState(() => _dropoffLocation = position);
  }

  void _onPickupMarkerDragEnd(LatLng position) {
    setState(() => _pickupLocation = position);
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
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
            markers: markers,
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
