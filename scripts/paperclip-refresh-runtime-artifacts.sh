#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_WRITER="$ROOT_DIR/scripts/paperclip-write-runtime-report.sh"
SNAPSHOT_WRITER="$ROOT_DIR/scripts/paperclip-write-runtime-snapshot.sh"
BLOCKED_WRITER="$ROOT_DIR/scripts/paperclip-write-blocked-update.sh"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-refresh-runtime-artifacts.sh [OUTPUT_DIR] [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]

Examples:
  ./scripts/paperclip-refresh-runtime-artifacts.sh
  ./scripts/paperclip-refresh-runtime-artifacts.sh reports
  ./scripts/paperclip-refresh-runtime-artifacts.sh \
    reports \
    osiris-paperclip-agent-key-secret-id \
    cursor-api-key-secret-id

Notes:
  - Writes both:
    - osiris-paperclip-runtime-report.md
    - osiris-paperclip-runtime-snapshot.json
    - osiris-paperclip-blocked-update.json
  - OUTPUT_DIR defaults to reports.
  - This is the single-command refresh path for blocked Paperclip heartbeats.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  usage
  exit 0
fi

output_dir="${1:-reports}"
paperclip_secret_id="${2:-YOUR_PAPERCLIP_SECRET_ID}"
cursor_secret_id="${3:-YOUR_CURSOR_SECRET_ID}"

if [[ ! -x "$REPORT_WRITER" ]]; then
  echo "error: missing helper: $REPORT_WRITER" >&2
  exit 1
fi

if [[ ! -x "$SNAPSHOT_WRITER" ]]; then
  echo "error: missing helper: $SNAPSHOT_WRITER" >&2
  exit 1
fi

if [[ ! -x "$BLOCKED_WRITER" ]]; then
  echo "error: missing helper: $BLOCKED_WRITER" >&2
  exit 1
fi

mkdir -p "$output_dir"

report_path="$output_dir/osiris-paperclip-runtime-report.md"
snapshot_path="$output_dir/osiris-paperclip-runtime-snapshot.json"
blocked_path="$output_dir/osiris-paperclip-blocked-update.json"

"$REPORT_WRITER" "$report_path" "$paperclip_secret_id" "$cursor_secret_id"
"$SNAPSHOT_WRITER" "$snapshot_path" "$paperclip_secret_id" "$cursor_secret_id"
"$BLOCKED_WRITER" "$blocked_path"

printf 'Refreshed runtime artifacts in %s\n' "$output_dir"
