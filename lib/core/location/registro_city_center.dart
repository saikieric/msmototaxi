import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Registro, SP city center — used as the default map camera position
/// before a screen's actual device location is available (or if it's
/// denied). Shared by the passenger and driver home screens so both maps
/// agree on where to fall back to.
/// Registro市（サンパウロ州）中心部の座標。各画面で実際の端末位置が
/// 取得できるまで（または権限が拒否された場合）の初期カメラ位置に使う。
/// 乗客用・ドライバー用ホーム画面の両方で共有し、フォールバック先を
/// 一致させる。
const registroCityCenter = LatLng(-24.4950, -47.8433);
