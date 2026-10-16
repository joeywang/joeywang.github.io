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
# Root-relative CSS does not load via file://. Prepare a self-contained print document.
mise exec -- bundle exec ruby scripts/prepare_resume_print.rb "$build_dir/site" "$build_dir/resume-print.html"
chmod -R a+rX "$build_dir"

"$chromium_bin" \
  --headless \
  --no-sandbox \
  --disable-gpu \
  --run-all-compositor-stages-before-draw \
  --virtual-time-budget=12000 \
  --no-pdf-header-footer \
  --print-to-pdf="$build_dir/resume.pdf" \
  "file://$build_dir/resume-print.html" >/dev/null 2>&1

if [[ ! -s "$build_dir/resume.pdf" ]]; then
  printf 'PDF generation failed: %s\n' "$output" >&2
  exit 1
fi
# Chromium snap writes within its accessible staging tree; copy only after export.
cp "$build_dir/resume.pdf" "$output"

printf 'Wrote %s\n' "$output"
