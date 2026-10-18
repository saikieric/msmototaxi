-- Restricts passenger-initiated UPDATEs on rides to "cancel a requested
-- ride" only. The original "passengers can update their own rides" policy
-- (20260901155514_init_schema.sql) had a USING clause but no WITH CHECK, so
-- once this PR made the passenger UPDATE path reachable (ride cancel), any
-- PostgREST call could also rewrite status to completed/in_progress, or
-- rewrite driver_id/fare columns, on a passenger's own ride.
--
-- 乗客起点のrides UPDATEを、「requestedの配車をキャンセルする」だけに
-- 制限する。元の「passengers can update their own rides」ポリシー
-- （20260901155514_init_schema.sql）はUSING句のみでWITH CHECKが無く、
-- 今回のPRで乗客のUPDATE経路（配車キャンセル）が実際に使われるように
-- なったことで、PostgREST経由の呼び出しがstatusをcompleted/in_progress
-- に書き換えたり、driver_id/運賃カラムを書き換えたりできてしまっていた。

drop policy "passengers can update their own rides" on public.rides;

-- USING limits which existing rows are even reachable: only the
-- passenger's own, still-`requested` ride. WITH CHECK limits what the
-- resulting row can look like: still their own ride, now `cancelled`.
-- USING句は既存のどの行が対象になるかを絞る: 本人の、まだ`requested`の
-- 配車のみ。WITH CHECK句は更新後の行がどうなれるかを絞る: 本人の配車の
-- まま、`cancelled`になったもののみ。
create policy "passengers can cancel their own requested rides"
  on public.rides for update
  using (auth.uid() = passenger_id and status = 'requested')
  with check (auth.uid() = passenger_id and status = 'cancelled');

-- WITH CHECK only ever sees the new row, not the old one, so the policy
-- above cannot by itself stop a passenger UPDATE from smuggling in a
-- changed driver_id or fare column alongside the status flip. This trigger
-- compares OLD and NEW and rejects a passenger-initiated update (auth.uid()
-- = the ride's passenger) that touches anything beyond status/
-- cancelled_at/cancellation_reason. Driver- or service-role-initiated
-- updates (auth.uid() is not the ride's passenger, or there's no JWT at
-- all) are untouched by this check.
--
-- WITH CHECKは新しい行しか見られず古い行と比較できないため、上のポリシー
-- だけではstatusの変更に便乗したdriver_idや運賃カラムの改ざんを防げない。
-- このトリガーはOLDとNEWを比較し、乗客起点の更新（auth.uid()がその配車の
-- passenger_idと一致する）でstatus/cancelled_at/cancellation_reason以外に
-- 触れている場合は拒否する。ドライバーやサービスロールによる更新
-- （auth.uid()がその配車のpassenger_idと一致しない、またはJWTが無い場合）
-- はこのチェックの対象外。
create function public.enforce_passenger_ride_cancel_only()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is distinct from old.passenger_id then
    return new;
  end if;

  if new.passenger_id is distinct from old.passenger_id
      or new.driver_id is distinct from old.driver_id
      or new.pickup_location is distinct from old.pickup_location
      or new.pickup_address is distinct from old.pickup_address
      or new.dropoff_location is distinct from old.dropoff_location
      or new.dropoff_address is distinct from old.dropoff_address
      or new.estimated_fare_cents is distinct from old.estimated_fare_cents
      or new.final_fare_cents is distinct from old.final_fare_cents
      or new.commission_rate is distinct from old.commission_rate
      or new.payment_method is distinct from old.payment_method
      or new.requested_at is distinct from old.requested_at
      or new.matched_at is distinct from old.matched_at
      or new.started_at is distinct from old.started_at
      or new.completed_at is distinct from old.completed_at then
    raise exception 'passengers may only cancel a requested ride';
  end if;

  return new;
end;
$$;

create trigger enforce_passenger_ride_cancel_only
  before update on public.rides
  for each row execute function public.enforce_passenger_ride_cancel_only();
