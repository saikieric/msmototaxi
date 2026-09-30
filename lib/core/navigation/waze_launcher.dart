import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Waze, pointed at [destination], via Google's documented Waze deep
/// link format. Returns whether the link was actually launched (`false` if
/// no handler accepted it, e.g. Waze isn't installed and no browser is
/// available to fall back to — extremely rare, but the caller should show
/// an error rather than assume success).
/// [destination] を目的地としてWazeを開く。Google公式のWazeディープリンク
/// 形式を使う。実際にリンクが起動できたかを返す（`false`は、Wazeが未
/// インストールでフォールバック先のブラウザも無い場合など、どのハンドラも
/// 受け付けなかった場合 — 極めて稀だが、呼び出し側は成功を前提にせず
/// エラー表示すること）。
///
/// This does NOT navigate from a specific origin to [destination] — Waze's
/// simple deep link only takes one coordinate and always routes from the
/// device's current position, the same way tapping a pin in the Waze app
/// itself would. There's no supported way to pass a separate start point
/// through this link format.
/// これは特定の出発地から[destination]へのルートを指定するものではない —
/// Wazeのシンプルなディープリンクは座標を1つしか受け取れず、常に端末の
/// 現在地からのルートになる（Wazeアプリ自体でピンをタップした場合と同じ）。
/// このリンク形式で別途出発地点を渡す方法は無い。
///
/// See https://developers.google.com/waze/deeplinks for the full spec.
/// 仕様の全体は https://developers.google.com/waze/deeplinks 参照。
Future<bool> launchWazeNavigation(LatLng destination) {
  final uri = Uri.https('waze.com', '/ul', {
    'll': '${destination.latitude},${destination.longitude}',
    'navigate': 'yes',
    // Lets Waze/Google attribute traffic from this integration if we ever
    // need support — see the deep link docs' "best practice" note.
    // この連携経由の流入をWaze/Google側で識別できるようにする —
    // ディープリンク仕様の「ベストプラクティス」の注記参照。
    'utm_source': 'motogo',
  });
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
