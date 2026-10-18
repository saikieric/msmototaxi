import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import 'ride.dart';

/// Writes and watches the signed-in passenger's ride.
/// ログイン中の乗客の配車を書き込み、監視する。
///
/// Existing RLS is enough: `passengers can create rides` checks
/// `auth.uid() = passenger_id`, `passengers can view their own rides`
/// covers the select (including Realtime), and
/// `passengers can update their own rides` covers cancel. No new policy.
/// 既存の RLS で足りる。`passengers can create rides` が
/// `auth.uid() = passenger_id` を検査し、`passengers can view their own
/// rides` が select（Realtime を含む）を、`passengers can update their
/// own rides` がキャンセルをカバーする。新しいポリシーは無い。
class RideRepository {
  RideRepository(this._client);

  final SupabaseClient _client;

  static RideRepository get instance => RideRepository(SupabaseConfig.client);

  /// Inserts a `requested` ride and returns the row PostgREST echoed back.
  /// `requested` の依頼を挿入し、PostgREST が返し直した行を返す。
  Future<Ride> create({
    required String passengerId,
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
  }) async {
    final row = await _client
        .from('rides')
        .insert(
          rideRequestRow(
            passengerId: passengerId,
            pickupLatitude: pickupLatitude,
            pickupLongitude: pickupLongitude,
            dropoffLatitude: dropoffLatitude,
            dropoffLongitude: dropoffLongitude,
          ),
        )
        .select('id, status')
        .single();
    return Ride.fromRow(row);
  }

  /// The passenger's newest ride that is not completed or cancelled.
  /// 完了でもキャンセルでもない、乗客の最新の依頼。
  Future<Ride?> findActive(String passengerId) async {
    final row = await _client
        .from('rides')
        .select('id, status')
        .eq('passenger_id', passengerId)
        .inFilter('status', activeRideStatusValues)
        .order('requested_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return Ride.fromRow(row);
  }

  /// Sets `status` to `cancelled`. The UI only calls this for `requested`.
  /// `status` を `cancelled` にする。UI は `requested` のときだけ呼ぶ。
  Future<Ride> cancel(String rideId, {DateTime? cancelledAt}) async {
    final row = await _client
        .from('rides')
        .update(
          rideCancelPatch(cancelledAt: cancelledAt ?? DateTime.now().toUtc()),
        )
        .eq('id', rideId)
        .select('id, status')
        .single();
    return Ride.fromRow(row);
  }

  /// Subscribes to Realtime changes for one ride.
  /// 1件の配車の Realtime 変更を購読する。
  ///
  /// The insert/cancel calls already return the new row; this is how a
  /// later status change (a driver match, for example) reaches the screen.
  /// Caller removes the channel on dispose.
  /// 挿入とキャンセルは新しい行を返す。これはその後のステータス変化
  /// （例えばドライバーのマッチ）を画面へ届けるためのもの。
  /// 呼び出し側は dispose でチャンネルを外す。
  RealtimeChannel watch(String rideId, void Function(Ride ride) onRide) {
    final channel = _client.channel('ride:$rideId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            onRide(Ride.fromRow(record));
          },
        )
        .subscribe();
    return channel;
  }
}
