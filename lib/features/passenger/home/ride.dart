/// Passenger-side view of a `rides` row, plus the payloads written to it.
/// 乗客側から見た `rides` の1行と、そこへ書き込むペイロード。
///
/// Matching, fares, and driver updates stay out of this file. The screen
/// only creates a `requested` ride, shows its status, and cancels while
/// it is still `requested`.
/// マッチング、運賃、ドライバー側の更新はこのファイルの外。画面が行うのは
/// `requested` の依頼作成、ステータス表示、`requested` の間のキャンセルだけ。
library;

/// Values of `public.ride_status`, in lifecycle order.
/// `public.ride_status` の値。ライフサイクル順。
enum RideStatus {
  requested,
  matched,
  enRoute,
  inProgress,
  completed,
  cancelled;

  /// Wire value stored in Postgres (snake_case, unlike the Dart name).
  /// Postgres に保存する値（Dart 名とは違い snake_case）。
  String get dbValue => switch (this) {
    RideStatus.requested => 'requested',
    RideStatus.matched => 'matched',
    RideStatus.enRoute => 'en_route',
    RideStatus.inProgress => 'in_progress',
    RideStatus.completed => 'completed',
    RideStatus.cancelled => 'cancelled',
  };

  static RideStatus parse(String value) => switch (value) {
    'requested' => RideStatus.requested,
    'matched' => RideStatus.matched,
    'en_route' => RideStatus.enRoute,
    'in_progress' => RideStatus.inProgress,
    'completed' => RideStatus.completed,
    'cancelled' => RideStatus.cancelled,
    _ => throw FormatException('Unknown ride status: $value'),
  };

  /// Statuses that still occupy the passenger. A new request waits.
  /// 乗客をまだ拘束するステータス。新規依頼は待つ。
  bool get isActive => switch (this) {
    RideStatus.requested ||
    RideStatus.matched ||
    RideStatus.enRoute ||
    RideStatus.inProgress => true,
    RideStatus.completed || RideStatus.cancelled => false,
  };
}

/// `ride_status` values passed to the "current ride" select filter.
/// 「現在の依頼」を選ぶ select のフィルタに渡す `ride_status` の値。
const activeRideStatusValues = [
  'requested',
  'matched',
  'en_route',
  'in_progress',
];

/// PostGIS EWKT for a WGS84 point.
/// WGS84 地点の PostGIS EWKT。
///
/// WKT order is longitude then latitude. Six decimal places is about 0.1 m
/// and avoids Dart's exponent notation, which PostGIS rejects.
/// WKT の順序は経度、緯度。小数6桁は約0.1mで、PostGIS が拒否する Dart の
/// 指数表記を避ける。
String geographyPoint({required double latitude, required double longitude}) {
  final lon = longitude.toStringAsFixed(6);
  final lat = latitude.toStringAsFixed(6);
  return 'SRID=4326;POINT($lon $lat)';
}

/// Row inserted into `rides` for a new passenger request.
/// 乗客の新規依頼として `rides` に挿入する行。
///
/// [passengerId] must be `auth.uid()` — the insert policy checks that.
/// Status is sent explicitly even though the column defaults to
/// `requested`.
/// [passengerId] は `auth.uid()` であること。挿入ポリシーがそれを検査する。
/// カラムのデフォルトが `requested` でも、ステータスは明示的に送る。
Map<String, dynamic> rideRequestRow({
  required String passengerId,
  required double pickupLatitude,
  required double pickupLongitude,
  required double dropoffLatitude,
  required double dropoffLongitude,
}) {
  return {
    'passenger_id': passengerId,
    'status': RideStatus.requested.dbValue,
    'pickup_location': geographyPoint(
      latitude: pickupLatitude,
      longitude: pickupLongitude,
    ),
    'dropoff_location': geographyPoint(
      latitude: dropoffLatitude,
      longitude: dropoffLongitude,
    ),
  };
}

/// Update applied when the passenger cancels a `requested` ride.
/// 乗客が `requested` の依頼をキャンセルするときの更新内容。
Map<String, dynamic> rideCancelPatch({required DateTime cancelledAt}) {
  return {
    'status': RideStatus.cancelled.dbValue,
    'cancelled_at': cancelledAt.toUtc().toIso8601String(),
  };
}

/// One `rides` row, limited to what the passenger home screen shows.
/// 乗客ホーム画面が表示する範囲に絞った `rides` の1行。
class Ride {
  const Ride({required this.id, required this.status});

  final String id;
  final RideStatus status;

  /// `requested` only. Later statuses are the driver's to move.
  /// `requested` の間だけ。それ以降はドライバー側が進める。
  bool get canCancel => status == RideStatus.requested;

  /// Still in progress: the passenger must not open a second request.
  /// 進行中。乗客は2件目の依頼を出さない。
  bool get isActive => status.isActive;

  factory Ride.fromRow(Map<String, dynamic> row) {
    final id = row['id'];
    final status = row['status'];
    if (id is! String || status is! String) {
      throw FormatException('Ride row is missing id or status: $row');
    }
    return Ride(id: id, status: RideStatus.parse(status));
  }
}
