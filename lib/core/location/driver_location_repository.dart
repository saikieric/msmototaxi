import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

/// Thin wrapper around the `driver_locations` table — UPSERTs the
/// signed-in driver's latest GPS fix while they're online (see
/// `DriverHomeScreen`'s online/offline toggle).
/// `driver_locations` テーブルの薄いラッパー — オンライン中のドライバーの
/// 最新GPS位置をUPSERTする（`DriverHomeScreen`のオンライン／オフライン
/// 切り替え参照）。
///
/// RLS on `driver_locations` (see
/// `supabase/migrations/20260901155514_init_schema.sql`) already allows a
/// driver to insert/update only their own row (`auth.uid() = driver_id`),
/// so no new policy is needed for this to work.
/// `driver_locations`のRLS（`supabase/migrations/20260901155514_init_schema.sql`
/// 参照）は既にドライバー本人の行のみ挿入／更新を許可している
/// （`auth.uid() = driver_id`）ため、これを動かすために新しいポリシーは
/// 不要。
class DriverLocationRepository {
  DriverLocationRepository(this._client);

  final SupabaseClient _client;

  static DriverLocationRepository get instance =>
      DriverLocationRepository(SupabaseConfig.client);

  /// Upserts [position] as [driverId]'s current location.
  /// [position] を [driverId] の現在位置としてUPSERTする。
  Future<void> upsert({required String driverId, required Position position}) {
    return _client
        .from('driver_locations')
        .upsert(driverLocationRow(driverId: driverId, position: position));
  }
}

/// Builds the row to UPSERT into `driver_locations` for [driverId] from a
/// geolocator [position]. Pure/no I/O so it's unit-testable without a
/// Supabase connection — see `test/driver_location_repository_test.dart`.
/// [driverId] 用に、geolocatorの [position] から `driver_locations` へ
/// UPSERTする行を組み立てる。I/Oを行わない純粋関数なので、Supabase接続無しで
/// 単体テスト可能 — `test/driver_location_repository_test.dart` 参照。
///
/// `location` is sent as WKT text (`POINT(lng lat)`); PostGIS registers an
/// implicit text->geography cast that parses it (defaulting to SRID 4326,
/// matching the column's `geography(point, 4326)` type), so no explicit
/// `ST_GeogFromText` call is needed on the client side.
/// `location` はWKTテキスト（`POINT(lng lat)`）として送る。PostGISは
/// text->geographyの暗黙キャストを登録しており、これが解析する（SRIDを
/// 省略するとデフォルト4326になり、カラムの`geography(point, 4326)`型と
/// 一致する）ため、クライアント側で明示的に`ST_GeogFromText`を呼ぶ必要は
/// 無い。
Map<String, dynamic> driverLocationRow({
  required String driverId,
  required Position position,
}) {
  return {
    'driver_id': driverId,
    'location': 'POINT(${position.longitude} ${position.latitude})',
    'heading': position.heading,
    'speed_kmh': position.speed * 3.6, // m/s -> km/h / m/s から km/h へ
    // Explicit, since UPSERT's ON CONFLICT DO UPDATE only refreshes columns
    // present in the payload — the column's `default now()` only fires on
    // the insert path, so without this, repeated pings would leave a
    // stale timestamp on every update after the first.
    // 明示的に指定する理由: UPSERTのON CONFLICT DO UPDATEはペイロードに
    // 含まれる列しか更新しない — 列の`default now()`はinsert時にしか
    // 発火しないため、これを指定しないと最初の更新以降、以後のping全てで
    // タイムスタンプが古いまま残ってしまう。
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}
