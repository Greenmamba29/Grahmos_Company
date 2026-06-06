#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_HELPER="$ROOT_DIR/scripts/paperclip-api.sh"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-write-blocked-update.sh OUTPUT_PATH [UNBLOCK_OWNER] [REQUIRED_ACTION] [DETAILS]

Examples:
  ./scripts/paperclip-write-blocked-update.sh reports/osiris-paperclip-blocked-update.json
  ./scripts/paperclip-write-blocked-update.sh \
    reports/osiris-paperclip-blocked-update.json \
    "Paperclip operator" \
    "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
    "Current Cursor Cloud shell has no board-authenticated Paperclip session and no injected PAPERCLIP_API_KEY."

Notes:
  - Writes the exact PATCH payload for marking an issue `blocked`.
  - Writes the default blocked-payload wording for the Cursor Cloud Paperclip auth case.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  usage
  exit 0
fi

output_path="${1:-}"
unblock_owner="${2:-Paperclip operator}"
required_action="${3:-Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env}"
details="${4:-Current Cursor Cloud shell has no board-authenticated Paperclip session and no injected PAPERCLIP_API_KEY. After the env change, rerun the heartbeat and continue the current issue with resume=true.}"

if [[ -z "$output_path" ]]; then
  echo "error: OUTPUT_PATH is required" >&2
  exit 2
fi

if [[ ! -x "$API_HELPER" ]]; then
  echo "error: missing helper: $API_HELPER" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_path")"
"$API_HELPER" blocked-template "$unblock_owner" "$required_action" "$details" >"$output_path"
printf 'Wrote %s\n' "$output_path"
