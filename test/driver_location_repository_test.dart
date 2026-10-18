// Unit test for driverLocationRow — the pure payload-building function
// behind DriverLocationRepository.upsert. No Supabase connection needed.
//
// driverLocationRow（DriverLocationRepository.upsertの背後にある純粋な
// ペイロード組み立て関数）の単体テスト。Supabase接続は不要。

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:msmototaxi/core/location/driver_location_repository.dart';

void main() {
  test('builds a WKT point and converts speed from m/s to km/h', () {
    final position = Position(
      longitude: -47.8433,
      latitude: -24.4950,
      timestamp: DateTime.utc(2026, 1, 1),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 90,
      headingAccuracy: 0,
      speed: 10, // m/s
      speedAccuracy: 0,
    );

    final row = driverLocationRow(driverId: 'driver-1', position: position);

    expect(row['driver_id'], 'driver-1');
    expect(row['location'], 'POINT(-47.8433 -24.495)');
    expect(row['heading'], 90);
    expect(row['speed_kmh'], closeTo(36, 0.0001)); // 10 m/s -> 36 km/h
    expect(row['updated_at'], isA<String>());
  });
}
