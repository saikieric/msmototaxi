---
name: run-msmototaxi
description: Build, run, and drive/screenshot the MotoGo Flutter app (msmototaxi) — passenger and driver flavors. Use when asked to run the app, launch MotoGo, screenshot a screen, verify a UI change actually renders, or check flutter analyze/flutter test pass. Covers both Android/iOS/Windows launch and headless web driving via Playwright.
---

All paths below are relative to `msmototaxi/` (this project's root — the
directory containing `pubspec.yaml`). This skill's own files live at
`.claude/skills/run-msmototaxi/`.

すべてのパスは `msmototaxi/`（このプロジェクトのルート、`pubspec.yaml` がある
ディレクトリ）からの相対パス。このスキル自体のファイルは
`.claude/skills/run-msmototaxi/` にある。

MotoGo is a Flutter app (passenger/driver flavors sharing one codebase —
see `lib/flavors.dart`) backed by Supabase, with a Google Maps view on the
passenger home screen. **There is no Android/iOS emulator or physical
device available in this environment** — the way to actually launch and
interact with the app here is the **web build**, driven headlessly with
Playwright via `.claude/skills/run-msmototaxi/driver.mjs`. That is the
primary agent path below. Windows-desktop and mobile builds are documented
as the human path since they need a display / SDK this environment lacks.

## Prerequisites (verified in this environment)

- Flutter is installed at `/c/flutter/bin` but **not on PATH** in the Bash
  tool's shell — prefix every `flutter`/`dart` command with:
  ```bash
  export PATH="$PATH:/c/flutter/bin"
  ```
- `.env` must exist with real Supabase + Google Maps values (copy
  `.env.example` and fill in) — see the project's own README for how to
  get them. Without it the app still boots (Supabase falls back to a
  "not configured" banner) but the map won't load.
- Node.js + npm (used for the Playwright driver, not the Flutter app
  itself).

## Build (web, passenger flavor)

```bash
export PATH="$PATH:/c/flutter/bin"
bash tool/gen_web_index.sh          # writes web/index.html with the Google Maps key from .env
flutter build web -t lib/main_passenger.dart
```
Swap `lib/main_passenger.dart` for `lib/main_driver.dart` to build the
driver flavor instead — same build command otherwise.

This produces static output in `build/web/`. It takes about a minute.

## Run (agent path): serve + drive headlessly with Playwright

The driver's own dependencies are separate from the Flutter app's — install
once:
```bash
cd .claude/skills/run-msmototaxi
npm install   # installs playwright into this skill dir's own node_modules
npx playwright install chromium   # one-time browser download, if not already present
```

Then, from `.claude/skills/run-msmototaxi/`:

```bash
# 1. Serve the build/web output (blocks — run in background)
node driver.mjs serve 8765 &

# 2. Screenshot whatever's currently on screen after the app boots
node driver.mjs screenshot "http://localhost:8765" "screenshots/login.png"

# 3. Click a point (pixel coords, 480x900 viewport) and screenshot the result
node driver.mjs click "http://localhost:8765" 240 579 "screenshots/passenger-home.png"
```

Screenshots land wherever you point the output path (relative to the
current shell's cwd). `screenshots/` in this skill dir is a reasonable
default and is gitignored-safe to write into repeatedly.

**Why pixel-coordinate clicks and not selectors:** Flutter's web build
renders the entire UI into a single `<canvas>` (CanvasKit renderer) — there
is no DOM tree of buttons/inputs to query by text or role. `driver.mjs`
clicks by `(x, y)` against a fixed 480×900 viewport. If you change the UI
layout, take a fresh `screenshot`, visually locate the new element's
position, and update the coordinates you pass to `click`.

Stop the server when done:
```bash
# find and kill the node process bound to the port you used
for pid in $(netstat -ano | grep "LISTENING" | grep ":8765" | awk '{print $5}' | sort -u); do
  taskkill //PID "$pid" //F
done
```

## Test & static analysis

```bash
export PATH="$PATH:/c/flutter/bin"
flutter analyze
flutter test
```
Both were verified clean in this environment (`flutter analyze`: no
issues; `flutter test`: 1/1 passed — a smoke test that renders the login
screen with Supabase mock-initialized).

## Run (human path): native builds

Requires a display / device this environment doesn't have — untested here,
documented from the project's own README:
```bash
flutter run --flavor passenger -t lib/main_passenger.dart   # Android/iOS
flutter run -d windows                                       # Windows desktop
flutter run                                                   # defaults to passenger flavor
```

## Gotchas

- **`flutter: command not found`** in the Bash tool even though Flutter is
  installed — the Bash tool's shell doesn't inherit the same PATH as a
  normal terminal here. Always `export PATH="$PATH:/c/flutter/bin"` first.
- **`python3 -m http.server` silently fails** (curl gets connection
  refused, no error printed) — `python3` on this machine resolves to a
  Windows Store stub, not a real interpreter. Use `driver.mjs serve`
  (Node) instead.
- **Google Maps won't render / console shows no map** — `web/index.html`
  is generated (gitignored) from `web/index.html.template` by
  `tool/gen_web_index.sh`, which reads `GOOGLE_MAPS_API_KEY` from `.env`.
  Forgetting to run that script after a fresh checkout, or after changing
  the key, leaves a stale or missing key baked into the build.
- **No fixed "app ready" signal from Flutter web** — `driver.mjs` waits
  for `networkidle` plus a flat 3s timeout before screenshotting/clicking.
  This was reliable in testing but is a guess, not a hook into the
  framework; bump the timeout if screenshots look like they caught the
  app mid-boot (blank canvas).
- **Location permission banner on the passenger home screen** is expected
  in this headless environment — Chromium has no real GPS, so the app
  shows "位置情報の権限が許可されていません" and lets you pick pickup by
  tapping the map instead. Not a bug to "fix" when driving headlessly.
