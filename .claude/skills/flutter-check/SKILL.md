---
name: flutter-check
description: Run flutter analyze and flutter test together for the MotoGo app (msmototaxi) and report pass/fail. Use when asked to check the code, verify it still works, run tests, run the linter/analyzer, or confirm a change didn't break anything, before committing.
---

All paths below are relative to `msmototaxi/` (this project's root — the
directory containing `pubspec.yaml`).

すべてのパスは `msmototaxi/`（`pubspec.yaml` があるこのプロジェクトの
ルート）からの相対パス。

## Prerequisites

Flutter is installed at `/c/flutter/bin` but is **not on PATH** in the Bash
tool's shell — prefix every command with:
```bash
export PATH="$PATH:/c/flutter/bin"
```

## Run

```bash
export PATH="$PATH:/c/flutter/bin"
cd msmototaxi
flutter analyze
flutter test
```

Verified in this environment: `flutter analyze` → `No issues found!`;
`flutter test` → `1/1 passed` (`test/widget_test.dart`, a smoke test that
renders the login screen with Supabase mock-initialized — see the file
itself for why it needs `SharedPreferences.setMockInitialValues` and
`dotenv.testLoad` before `Supabase.initialize`).

Run both every time — `analyze` catches type/lint issues `test` won't, and
vice versa. Report exact output (pass/fail counts, error text) rather than
summarizing "it works."

## Gotchas

- **`flutter: command not found`** even though Flutter is installed — the
  Bash tool's shell doesn't inherit the same PATH as a normal terminal
  here. Always `export PATH="$PATH:/c/flutter/bin"` first, every fresh
  shell — it does not persist between separate Bash tool invocations.
- If `flutter test` fails with `MissingPluginException` on
  `shared_preferences` or `NotInitializedError` on `dotenv.env`, that's
  `test/widget_test.dart`'s `setUpAll` not running (or having been edited
  to drop the mocks) — `supabase_flutter` needs both
  `SharedPreferences.setMockInitialValues({})` and `dotenv.testLoad(...)`
  before `Supabase.initialize` under `flutter test`, since there's no real
  platform plugin or `.env` asset available in that environment.
