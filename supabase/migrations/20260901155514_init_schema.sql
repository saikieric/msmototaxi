-- Initial schema for MotoGo (moto-taxi dispatch app for Registro, SP).
-- MotoGo（Registro市向け配車アプリ）の初期スキーマ。
--
-- See slides/slides.md ("アプリの仕組み" / "技術スタック") for the intended
-- architecture: PostgreSQL + PostGIS for geo search, Supabase Auth for
-- phone/email login, Realtime for driver location + ride status updates.
-- 想定アーキテクチャは slides/slides.md「アプリの仕組み」「技術スタック」を参照。
-- PostGISで地理検索、Supabase Authで電話番号/メール認証、
-- Realtimeでドライバー位置情報・配車ステータスを配信する。

-- ============================================================================
-- Extensions / 拡張機能
-- ============================================================================

create extension if not exists postgis with schema extensions;

-- ============================================================================
-- Enums
-- ============================================================================

create type public.user_role as enum ('passenger', 'driver');

create type public.driver_status as enum ('offline', 'online', 'on_trip');

create type public.ride_status as enum (
  'requested',   -- 乗客が依頼を作成した直後 / just created by passenger
  'matched',     -- ドライバーが割り当てられた / a driver has been assigned
  'en_route',    -- ドライバーが乗車地点へ向かっている / driver heading to pickup
  'in_progress', -- 乗客を乗せて走行中 / passenger picked up, trip underway
  'completed',   -- 完了 / finished normally
  'cancelled'    -- 乗客/ドライバーいずれかがキャンセル / cancelled by either side
);

create type public.payment_method as enum ('cash', 'pix');

-- ============================================================================
-- profiles: one row per auth user, shared by passengers and drivers.
-- profiles: authユーザー1件につき1行。乗客・ドライバー共通。
-- ============================================================================

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null,
  full_name text,
  phone text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Shared profile for both passengers and drivers, keyed by auth.users.id. / 乗客・ドライバー共通のプロフィール（auth.users.idと1:1）。';

-- ============================================================================
-- driver_profiles: driver-specific details, 1:1 with profiles where role='driver'.
-- driver_profiles: ドライバー固有情報。role='driver'のprofilesと1:1。
-- ============================================================================

create table public.driver_profiles (
  id uuid primary key references public.profiles (id) on delete cascade,
  vehicle_plate text,
  vehicle_model text,
  status public.driver_status not null default 'offline',
  -- Set by an operator once the driver's documents/vehicle are vetted.
  -- 運営がドライバーの書類・車両を確認した後に true にする。
  is_approved boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.driver_profiles is
  'Driver-specific fields (vehicle, online status, approval). / ドライバー固有の情報（車両、稼働状態、承認状況）。';

-- ============================================================================
-- driver_locations: latest known position per driver (UPSERTed on each GPS
-- ping), used for PostGIS-based nearest-driver matching + Realtime broadcast.
-- driver_locations: ドライバーごとの最新位置（GPS更新のたびにUPSERT）。
-- PostGISによる近傍ドライバー検索とRealtime配信に使う。
-- ============================================================================

create table public.driver_locations (
  driver_id uuid primary key references public.driver_profiles (id) on delete cascade,
  location extensions.geography(point, 4326) not null,
  heading double precision, -- degrees, 0-360 / 進行方位角（度）
  speed_kmh double precision,
  updated_at timestamptz not null default now()
);

comment on table public.driver_locations is
  'Latest position per driver (one row each, UPSERTed on every ping). / ドライバーごとの最新位置（1行ずつ、更新のたびにUPSERT）。';

-- Spatial index for "nearest available driver" queries.
-- 「近くの空車ドライバー」検索用の空間インデックス。
create index driver_locations_location_idx
  on public.driver_locations using gist (location);

-- ============================================================================
-- rides: one ride request from a passenger, through matching to completion.
-- rides: 乗客の配車依頼1件。マッチングから完了までを表す。
-- ============================================================================

create table public.rides (
  id uuid primary key default gen_random_uuid(),
  passenger_id uuid not null references public.profiles (id),
  driver_id uuid references public.driver_profiles (id),
  status public.ride_status not null default 'requested',

  pickup_location extensions.geography(point, 4326) not null,
  pickup_address text,
  dropoff_location extensions.geography(point, 4326) not null,
  dropoff_address text,

  -- Fare breakdown. Filled in once the ride completes (or estimated at
  -- request time) — see slides.md "Registroでの利益率" for the pricing model.
  -- 運賃内訳。完了時（または依頼時点の見積もり）に確定する。
  -- 料金モデルは slides.md「Registroでの利益率」参照。
  estimated_fare_cents integer,
  final_fare_cents integer,
  commission_rate numeric(4, 3), -- e.g. 0.15 = 15% / 例: 0.15 = 15%
  payment_method public.payment_method,

  requested_at timestamptz not null default now(),
  matched_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.rides is
  'A single ride request, from creation through matching to completion. / 配車依頼1件（作成〜マッチング〜完了まで）。';

create index rides_passenger_id_idx on public.rides (passenger_id);
create index rides_driver_id_idx on public.rides (driver_id);
create index rides_status_idx on public.rides (status);

-- ============================================================================
-- updated_at auto-touch trigger, applied to every table that has the column.
-- updated_at自動更新トリガー。該当カラムを持つ全テーブルに適用。
-- ============================================================================

create function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger set_updated_at
  before update on public.driver_profiles
  for each row execute function public.set_updated_at();

create trigger set_updated_at
  before update on public.rides
  for each row execute function public.set_updated_at();

-- ============================================================================
-- New-user bootstrap: create a matching profiles row on signup.
-- 新規ユーザー登録時にprofilesを自動作成する。
--
-- The role defaults to 'passenger' unless the client passes
-- `data: {role: 'driver'}` to signUp/signInWithOtp — the driver flavor app
-- should do this so driver signups land in driver_profiles too.
-- role はデフォルトで 'passenger'。クライアント側で signUp/signInWithOtp に
-- `data: {role: 'driver'}` を渡した場合のみ 'driver' になる。
-- ドライバー用flavorアプリはこれを渡し、driver_profilesも自動作成させる。
-- ============================================================================

create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  new_role public.user_role;
begin
  new_role := coalesce(
    (new.raw_user_meta_data ->> 'role')::public.user_role,
    'passenger'
  );

  insert into public.profiles (id, role, full_name, phone)
  values (new.id, new_role, new.raw_user_meta_data ->> 'full_name', new.phone);

  if new_role = 'driver' then
    insert into public.driver_profiles (id) values (new.id);
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- Row Level Security
-- ============================================================================

alter table public.profiles enable row level security;
alter table public.driver_profiles enable row level security;
alter table public.driver_locations enable row level security;
alter table public.rides enable row level security;

-- profiles: everyone can read (needed to show driver name to a matched
-- passenger, etc.); a user can only edit their own row.
-- profiles: 全員が閲覧可能（マッチング相手の氏名表示等に必要）。
-- 編集は本人のみ。
create policy "profiles are viewable by everyone"
  on public.profiles for select
  using (true);

create policy "users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- driver_profiles: readable by everyone (passengers need to see driver
-- vehicle info); only the driver themself can update their own row.
-- driver_profiles: 全員が閲覧可能（乗客が車両情報を見る必要があるため）。
-- 更新は本人のドライバーのみ。
create policy "driver profiles are viewable by everyone"
  on public.driver_profiles for select
  using (true);

create policy "drivers can update their own driver profile"
  on public.driver_profiles for update
  using (auth.uid() = id);

-- driver_locations: readable by everyone (passengers need nearby drivers on
-- the map); only the driver themself can write their own location.
-- driver_locations: 全員が閲覧可能（乗客が地図上で近くのドライバーを見るため）。
-- 書き込みは本人のドライバーのみ。
create policy "driver locations are viewable by everyone"
  on public.driver_locations for select
  using (true);

create policy "drivers can upsert their own location"
  on public.driver_locations for insert
  with check (auth.uid() = driver_id);

create policy "drivers can update their own location"
  on public.driver_locations for update
  using (auth.uid() = driver_id);

-- rides: visible only to the passenger who requested it and the driver
-- assigned to it (or unassigned rides, visible to any driver so they can be
-- offered the request — matching logic will narrow this further in an Edge
-- Function).
-- rides: 依頼した乗客本人と、割り当てられたドライバーのみ閲覧可能。
-- 未割当のrideは全ドライバーに見える（依頼を提示するため）。
-- 実際の絞り込みはEdge Function側のマッチングロジックで行う。
create policy "passengers can view their own rides"
  on public.rides for select
  using (auth.uid() = passenger_id);

create policy "drivers can view assigned or unassigned rides"
  on public.rides for select
  using (auth.uid() = driver_id or driver_id is null);

create policy "passengers can create rides"
  on public.rides for insert
  with check (auth.uid() = passenger_id);

create policy "passengers can update their own rides"
  on public.rides for update
  using (auth.uid() = passenger_id);

create policy "assigned drivers can update their rides"
  on public.rides for update
  using (auth.uid() = driver_id);

-- ============================================================================
-- Realtime: broadcast changes on these tables to subscribed clients.
-- Realtime: これらのテーブルの変更をsubscribe中のクライアントに配信する。
-- ============================================================================

alter publication supabase_realtime add table public.driver_locations;
alter publication supabase_realtime add table public.rides;
