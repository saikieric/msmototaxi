import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import 'ride.dart';

/// Writes and watches the signed-in passenger's ride.
/// ログイン中の乗客の配車を書き込み、監視する。
///
/// `passengers can create rides` checks `auth.uid() = passenger_id`,
/// `passengers can view their own rides` covers the select (including
/// Realtime), and cancel is covered by
/// `passengers can cancel their own requested rides` (see
/// `supabase/migrations/*_restrict_passenger_ride_update.sql`) plus this
/// repo's own `.eq('status', 'requested')` filter in [cancel] — the policy
/// enforces it server-side even if a caller skips this repo.
/// `passengers can create rides` が `auth.uid() = passenger_id` を検査し、
/// `passengers can view their own rides` が select（Realtime を含む）を
/// カバーする。キャンセルは `passengers can cancel their own requested
/// rides`（`supabase/migrations/*_restrict_passenger_ride_update.sql`
/// 参照）と、[cancel] 内の `.eq('status', 'requested')` フィルターの
/// 二重でカバーする — このリポジトリを経由しない呼び出しでも、ポリシー側で
/// サーバー側に強制される。
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

  /// Sets `status` to `cancelled`. The UI only calls this for `requested`,
  /// but the `.eq('status', 'requested')` filter re-asserts that server-side
  /// too, so a stale client (or a race with a driver match) can't cancel a
  /// ride that has already moved past `requested`.
  /// `status` を `cancelled` にする。UI は `requested` のときだけ呼ぶが、
  /// `.eq('status', 'requested')` フィルターでサーバー側でもそれを
  /// 再確認する。これにより、古いクライアントの状態や、ドライバーの
  /// マッチングとの競合があっても、既に `requested` を過ぎた配車を
  /// キャンセルできないようにする。
  Future<Ride> cancel(String rideId, {DateTime? cancelledAt}) async {
    final row = await _client
        .from('rides')
        .update(
          rideCancelPatch(cancelledAt: cancelledAt ?? DateTime.now().toUtc()),
        )
        .eq('id', rideId)
        .eq('status', 'requested')
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
