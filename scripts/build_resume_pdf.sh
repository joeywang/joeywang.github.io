#!/usr/bin/env bash
set -euo pipefail

output="${1:-assets/pdf/JoeyW-dev.pdf}"
output="$(realpath -m "$output")"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cache_root="${RESUME_BUILD_ROOT:-$HOME/joey-resume-build}"
mkdir -p "$cache_root"
build_dir="$(mktemp -d "$cache_root/joey-resume-build.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT

if [[ "${CHROMIUM_BIN:-}" != "" ]]; then
  chromium_bin="$CHROMIUM_BIN"
elif command -v chromium >/dev/null 2>&1; then
  chromium_bin="$(command -v chromium)"
elif [[ -x /snap/bin/chromium ]]; then
  chromium_bin="/snap/bin/chromium"
else
  printf 'Chromium is required; set CHROMIUM_BIN to its executable path.\n' >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"
cd "$repo_root"
mise exec -- bundle exec jekyll build --destination "$build_dir/site"
chmod -R a+rX "$build_dir"

"$chromium_bin" \
  --headless \
  --no-sandbox \
  --disable-gpu \
  --run-all-compositor-stages-before-draw \
  --virtual-time-budget=12000 \
  --print-to-pdf="$output" \
  "file://$build_dir/site/resume.html" >/dev/null 2>&1

if [[ ! -s "$output" ]]; then
  printf 'PDF generation failed: %s\n' "$output" >&2
  exit 1
fi

printf 'Wrote %s\n' "$output"
