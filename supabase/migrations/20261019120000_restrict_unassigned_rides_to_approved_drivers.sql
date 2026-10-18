-- Restrict unassigned-ride visibility to approved drivers only.
-- 未割当ride（driver_id is null）の閲覧を承認済みドライバーのみに制限する。
--
-- Context: login currently uses signInAnonymously with a self-reported
-- `role` (see core/auth/auth_repository.dart) — any anonymous session can
-- claim role='driver', which previously meant any anonymous user could
-- read every unassigned ride's pickup/dropoff location via the
-- "drivers can view assigned or unassigned rides" policy. This migration
-- narrows that policy to require role='driver' AND
-- driver_profiles.is_approved = true, so an unverified self-reported
-- driver role is no longer sufficient on its own.
-- 背景: ログインは現在、自己申告の`role`付きのsignInAnonymouslyを使っている
-- （core/auth/auth_repository.dart参照）— 匿名セッションであれば誰でも
-- role='driver'を名乗れるため、従来は「drivers can view assigned or
-- unassigned rides」ポリシー経由で誰でも全未割当rideの乗車/降車位置を
-- 読めてしまっていた。このマイグレーションはそのポリシーを、
-- role='driver' かつ driver_profiles.is_approved = true であることを
-- 要求するように絞り込む。自己申告のdriverロールだけでは不十分にする。

drop policy "drivers can view assigned or unassigned rides" on public.rides;

create policy "drivers can view assigned or unassigned rides"
  on public.rides for select
  using (
    auth.uid() = driver_id
    or (
      driver_id is null
      and exists (
        select 1
        from public.driver_profiles dp
        join public.profiles p on p.id = dp.id
        where dp.id = auth.uid()
          and p.role = 'driver'
          and dp.is_approved
      )
    )
  );
