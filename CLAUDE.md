# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MotoGo: a moto-taxi ride-hailing app for Registro, São Paulo (Brazil).
Passenger and driver apps share a single Flutter codebase, built as
separate flavors. Backend is Supabase (Postgres + PostGIS + Auth +
Realtime), region `sa-east-1` (São Paulo). Product/business background
(target area, pricing model, competitive landscape) lives in
`../slides/slides.md`, a sibling directory that is **not** part of this
git repo — read it when you need the "why."

This repo is developed on Windows without an Android/iOS emulator or a
Mac; see the notes below before assuming a mobile build path works here.

## Commands

Flutter is at `/c/flutter/bin` but not on PATH in most non-interactive
shells — prefix commands with `export PATH="$PATH:/c/flutter/bin"`.

```bash
flutter analyze                                              # static analysis
flutter test                                                 # runs test/widget_test.dart
flutter test --plain-name "Shows the login screen"           # a single test by name

bash tool/gen_web_index.sh                                   # regenerate web/index.html with the Google Maps key from .env — required before any web build/run
flutter run -d chrome -t lib/main_passenger.dart              # run passenger flavor in Chrome (no emulator needed)
flutter run -d chrome -t lib/main_driver.dart                 # run driver flavor in Chrome
flutter build web -t lib/main_passenger.dart                  # web build -> build/web/

flutter run --flavor passenger -t lib/main_passenger.dart     # Android (needs a device/emulator this environment lacks)
flutter run -d windows                                        # Windows desktop (needs Developer Mode enabled — see Gotchas)

supabase login --token <token> --name "msmototaxi-dev"        # required every fresh shell — see Gotchas
supabase migration new <description>                          # new file under supabase/migrations/
supabase db push                                               # apply local migrations to the linked project
supabase migration list                                        # compare local vs remote
```

Three project skills wrap these with more detail and environment-specific
gotchas, verified working in this environment: `run-msmototaxi` (build +
headless Playwright driving/screenshots — see there for why pixel-coordinate
clicks are used instead of selectors on Flutter web), `flutter-check`
(analyze + test), `supabase-migrate` (migrations). `project-conventions`
documents the directory layout and the bilingual-comment style below.

## Architecture

**Flavor split.** `lib/flavors.dart` defines `Flavor.passenger` /
`Flavor.driver` and an `AppConfig` singleton set once at startup.
`lib/main_passenger.dart` / `lib/main_driver.dart` are the real
entrypoints; `lib/main.dart` just aliases the passenger flavor for
convenience. Both flavors run the same `MotoGoApp` (`lib/app.dart`) and
differ only through `AppConfig.instance.flavor` — e.g. `app_router.dart`
picks `/passenger` vs `/driver` as the post-login route based on it.
Android has matching `productFlavors` (applicationId suffix + display
name) in `android/app/build.gradle.kts`; iOS flavor/scheme setup does not
exist yet (needs Xcode on a Mac — see README).

**Routing is auth-state-driven, not just declarative.** `app_router.dart`
builds one `GoRouter` whose `redirect` callback reads Supabase auth state
(via `authStateProvider`/`currentUserProvider` in `core/auth/auth_state.dart`)
and bounces between `/login` and the flavor's home route. A
`GoRouterRefreshStream` bridges the Riverpod auth stream to go_router's
`Listenable`-based `refreshListenable` so redirects re-evaluate on
sign-in/out without manual navigation calls.

**Dev auth bypass — temporary, load-bearing.** Phone-OTP login is
implemented (`core/auth/auth_repository.dart`), but Supabase's SMS
provider isn't configured yet, so `core/auth/dev_auth_bypass.dart`
provides a `devAuthBypassProvider` that `app_router.dart`'s redirect logic
treats as equivalent to being signed in. The login screen's button
currently just flips this flag instead of doing real OTP. This means
screens past login (e.g. `PassengerHomeScreen`) run **without** a real
`auth.uid()` — anything that needs to write to a table with an
`auth.uid() = ...` RLS policy (see `rides`) will fail until real auth
replaces this bypass. Don't build features that assume a real signed-in
user without accounting for this.

**Supabase config is `.env`-driven with a graceful "unconfigured" state.**
`core/supabase/supabase_config.dart` reads `SUPABASE_URL`/`SUPABASE_ANON_KEY`
from `.env` (loaded as a Flutter asset, not compiled in) and falls back to
placeholder values if unset, so the app still boots without a real backend
— `SupabaseConfig.isConfigured` lets UI show a "not connected" state
instead of crashing. The Google Maps key follows a *different* pattern
per platform because it can't go through `.env` the same way — see
README's table (Android: `android/local.properties`, iOS: inline in
`AppDelegate.swift` for now, Web: baked into a gitignored `web/index.html`
generated from `web/index.html.template` by `tool/gen_web_index.sh`,
which must be re-run whenever the key changes).

**DB schema** (`supabase/migrations/20260901155514_init_schema.sql`):
`profiles` (1:1 with `auth.users`, has `role` enum) → `driver_profiles`
(1:1 with profiles where role='driver'; vehicle info, `status`,
`is_approved`) → `driver_locations` (1 row per driver, UPSERTed on each
GPS ping, `geography(point)` + GiST index for nearest-driver queries) and
`rides` (full lifecycle: `requested`→`matched`→`en_route`→`in_progress`→
`completed`/`cancelled`, plus fare/commission fields). A trigger
auto-creates `profiles` (and `driver_profiles` if `role: 'driver'` was
passed at signup) on `auth.users` insert. RLS is enabled on every table;
`driver_locations` and `rides` are registered on the `supabase_realtime`
publication for live client updates. Ride creation and PostGIS-based
matching (planned as an Edge Function) are not implemented yet — the
passenger home screen's "配車を依頼する" button is currently a stub (see
`PassengerHomeScreen._requestRide`).

**Passenger home screen state machine**
(`features/passenger/home/passenger_home_screen.dart`): pickup defaults to
device GPS (via `geolocator`, draggable marker once set); tapping the map
sets dropoff; the request button enables only once both are set. Location
permission/service failures degrade to "tap the map to pick a point
manually" rather than blocking the screen.

## Style

Every doc comment, file-level comment, and non-trivial inline comment is
written twice: an English sentence/paragraph immediately followed by its
Japanese translation (see any file under `lib/` for the shape). Code
identifiers stay English-only; user-facing UI strings are Japanese-only
(this is a Japanese-market app for a Brazilian city — see slides.md);
commit messages are English-only. Full detail in the
`project-conventions` skill.

## Gotchas

- **Windows desktop builds need Developer Mode** (`start
  ms-settings:developers` → enable) — without it, `flutter run -d windows`
  fails with `Error: Building with plugins requires symlink support.`
  Chrome (`-d chrome`) doesn't have this requirement and is the easier
  default for seeing the app run in this environment.
- **Supabase CLI login does not persist across shells** here — re-run
  `supabase login --token ...` before any `supabase db push`, even if you
  logged in earlier in the same session.
- **`python3 -m http.server` silently fails** on this machine (`python3`
  resolves to a Windows Store stub) — use the Node-based server in the
  `run-msmototaxi` skill's `driver.mjs` instead.
