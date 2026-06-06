#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_CHECK="$ROOT_DIR/scripts/paperclip-runtime-check.sh"
REFRESH_ARTIFACTS="$ROOT_DIR/scripts/paperclip-refresh-runtime-artifacts.sh"
API_HELPER="$ROOT_DIR/scripts/paperclip-api.sh"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-heartbeat-next-action.sh [OUTPUT_DIR] [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]

Examples:
  ./scripts/paperclip-heartbeat-next-action.sh
  ./scripts/paperclip-heartbeat-next-action.sh reports
  ./scripts/paperclip-heartbeat-next-action.sh \
    reports \
    osiris-paperclip-agent-key-secret-id \
    cursor-api-key-secret-id

Behavior:
  - Runs `paperclip-runtime-check.sh --json`
  - If issue operations are blocked, refreshes both canonical runtime artifacts
    and the standalone blocked issue-update payload
  - If the API-helper auth path is ready, prints the current-issue playbook
  - If only run visibility is available, prints a warning instead of a false ready state

Notes:
  - OUTPUT_DIR defaults to reports.
  - This is the preferred single-command heartbeat entry point.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  usage
  exit 0
fi

output_dir="${1:-reports}"
paperclip_secret_id="${2:-YOUR_PAPERCLIP_SECRET_ID}"
cursor_secret_id="${3:-YOUR_CURSOR_SECRET_ID}"

if [[ ! -x "$RUNTIME_CHECK" ]]; then
  echo "error: missing helper: $RUNTIME_CHECK" >&2
  exit 1
fi

if [[ ! -x "$REFRESH_ARTIFACTS" ]]; then
  echo "error: missing helper: $REFRESH_ARTIFACTS" >&2
  exit 1
fi

if [[ ! -x "$API_HELPER" ]]; then
  echo "error: missing helper: $API_HELPER" >&2
  exit 1
fi

diagnosis_file="$(mktemp)"
runtime_status=0
if "$RUNTIME_CHECK" --json >"$diagnosis_file"; then
  runtime_status=0
else
  runtime_status=$?
fi

diagnosis="$(python3 - "$diagnosis_file" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
print(data.get("diagnosis", "unknown"))
PY
)"

blocked_flag="$(python3 - "$diagnosis_file" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
print("true" if data.get("issue_operations_blocked") else "false")
PY
)"

next_action_state="$(python3 - "$diagnosis_file" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
print(data.get("heartbeat_next_action_state", "refresh_blocked_artifacts"))
PY
)"

printf 'Runtime diagnosis: %s (exit %s)\n' "$diagnosis" "$runtime_status"

if [[ "$next_action_state" == "refresh_blocked_artifacts" || "$blocked_flag" == "true" ]]; then
  "$REFRESH_ARTIFACTS" "$output_dir" "$paperclip_secret_id" "$cursor_secret_id"
  cat <<EOF
Heartbeat disposition: blocked on Paperclip auth.
Refreshed artifacts:
  - $output_dir/osiris-paperclip-runtime-report.md
  - $output_dir/osiris-paperclip-runtime-snapshot.json
  - $output_dir/osiris-paperclip-blocked-update.json
  - $output_dir/osiris-paperclip-runtime-latest.json
Latest manifest:
  - $output_dir/osiris-paperclip-runtime-latest.json
Unblock owner: Paperclip operator
Required action: inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env.
EOF
  rm -f "$diagnosis_file"
  exit 0
fi

if [[ "$next_action_state" == "warn_session_only" ]]; then
  cat <<EOF
Heartbeat disposition: run visibility available, but Paperclip API helper is not ready.
Run-scoped reads succeeded, but shell issue helpers still require PAPERCLIP_API_KEY.
Recommended next action: inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env, then rerun this command.
EOF
  rm -f "$diagnosis_file"
  exit 0
fi

echo "Heartbeat disposition: issue operations available via API helper."
"$API_HELPER" current-issue-playbook
rm -f "$diagnosis_file"
