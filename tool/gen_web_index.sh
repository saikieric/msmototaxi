#!/usr/bin/env bash
# Generates web/index.html from web/index.html.template, substituting
# {{GOOGLE_MAPS_API_KEY}} with the value from .env.
#
# web/index.html.template から web/index.html を生成し、
# {{GOOGLE_MAPS_API_KEY}} を .env の値に置き換える。
#
# Run this after every change to GOOGLE_MAPS_API_KEY in .env, and before
# `flutter run -d chrome` / `flutter build web` on a fresh checkout — the
# generated web/index.html is gitignored (see README).
#
# .envのGOOGLE_MAPS_API_KEYを変更するたびに、また新規clone直後に
# `flutter run -d chrome` / `flutter build web` を実行する前にこれを
# 実行すること。生成されるweb/index.htmlはgitignore対象（README参照）。
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(dirname "$script_dir")"

env_file="$project_root/.env"
template="$project_root/web/index.html.template"
output="$project_root/web/index.html"

if [[ ! -f "$env_file" ]]; then
  echo "Error: $env_file not found. Copy .env.example to .env and fill it in." >&2
  exit 1
fi

api_key=$(grep -E '^GOOGLE_MAPS_API_KEY=' "$env_file" | head -n1 | cut -d= -f2-)

if [[ -z "${api_key:-}" ]]; then
  echo "Error: GOOGLE_MAPS_API_KEY not set in $env_file." >&2
  exit 1
fi

sed "s|{{GOOGLE_MAPS_API_KEY}}|$api_key|g" "$template" > "$output"

echo "Generated $output"
