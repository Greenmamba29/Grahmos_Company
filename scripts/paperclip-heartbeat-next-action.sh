#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_CHECK="$ROOT_DIR/scripts/paperclip-runtime-check.sh"
REFRESH_ARTIFACTS="$ROOT_DIR/scripts/paperclip-refresh-runtime-artifacts.sh"
API_HELPER="$ROOT_DIR/scripts/paperclip-api.sh"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-heartbeat-next-action.sh [--json] [OUTPUT_DIR] [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]

Examples:
  ./scripts/paperclip-heartbeat-next-action.sh
  ./scripts/paperclip-heartbeat-next-action.sh --json
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
  - Use `--json` for a machine-readable next-action result.
EOF
}

json_mode=0
case "${1:-}" in
  --json)
    json_mode=1
    shift
    ;;
esac

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

emit_json() {
  local action_state="$1"
  local heartbeat_disposition="$2"
  local message="$3"
  local manifest_path="$4"
  local playbook_text="${5:-}"
  local playbook_command="${6:-}"
  local extra_json_path="${7:-}"
  python3 - "$diagnosis_file" "$action_state" "$heartbeat_disposition" "$message" "$output_dir" "$manifest_path" "$playbook_text" "$playbook_command" "$extra_json_path" <<'PY'
import json
import sys
from pathlib import Path

diagnosis = json.load(open(sys.argv[1]))
action_state = sys.argv[2]
heartbeat_disposition = sys.argv[3]
message = sys.argv[4]
output_dir = sys.argv[5]
manifest_path = sys.argv[6]
playbook_text = sys.argv[7]
playbook_command = sys.argv[8]
extra_json_path = sys.argv[9]

payload = {
    "schema_version": 1,
    "artifact_type": "paperclip_heartbeat_next_action",
    "diagnosis": diagnosis,
    "heartbeat_disposition": heartbeat_disposition,
    "next_action_state": action_state,
    "message": message,
    "output_dir": output_dir,
}

if manifest_path:
    latest_manifest = json.load(open(manifest_path))
    payload["artifacts"] = {
        "report_path": str(Path(output_dir) / "osiris-paperclip-runtime-report.md"),
        "snapshot_path": str(Path(output_dir) / "osiris-paperclip-runtime-snapshot.json"),
        "blocked_update_path": str(Path(output_dir) / "osiris-paperclip-blocked-update.json"),
        "latest_manifest_path": manifest_path,
    }
    payload["latest_manifest"] = latest_manifest
    blocked_update_path = Path(output_dir) / "osiris-paperclip-blocked-update.json"
    if blocked_update_path.exists():
        payload["blocked_update_payload"] = json.load(open(blocked_update_path))
    payload["recommended_commands"] = [
        "./scripts/paperclip-heartbeat-next-action.sh reports YOUR_PAPERCLIP_SECRET_ID [YOUR_CURSOR_SECRET_ID]",
        "./scripts/paperclip-heartbeat-next-action.sh --json reports YOUR_PAPERCLIP_SECRET_ID [YOUR_CURSOR_SECRET_ID]",
    ]

if playbook_command:
    payload["playbook_command"] = playbook_command
if playbook_text:
    payload["playbook_text"] = playbook_text
if extra_json_path:
    payload.update(json.load(open(extra_json_path)))

if action_state == "warn_session_only":
    payload["recommended_commands"] = [
        "./scripts/paperclip-heartbeat-next-action.sh reports YOUR_PAPERCLIP_SECRET_ID [YOUR_CURSOR_SECRET_ID]",
        "./scripts/paperclip-heartbeat-next-action.sh --json reports YOUR_PAPERCLIP_SECRET_ID [YOUR_CURSOR_SECRET_ID]",
    ]

if action_state == "current_issue_playbook" and "playbook_commands" in payload:
    payload["recommended_commands"] = payload["playbook_commands"]

json.dump(payload, sys.stdout, indent=2)
sys.stdout.write("\n")
PY
}

if [[ "$json_mode" != "1" ]]; then
  printf 'Runtime diagnosis: %s (exit %s)\n' "$diagnosis" "$runtime_status"
fi

if [[ "$next_action_state" == "refresh_blocked_artifacts" || "$blocked_flag" == "true" ]]; then
  refresh_log_file="$(mktemp)"
  if [[ "$json_mode" == "1" ]]; then
    if "$REFRESH_ARTIFACTS" --json "$output_dir" "$paperclip_secret_id" "$cursor_secret_id" >"$refresh_log_file"; then
      :
    else
      cat "$refresh_log_file" >&2
      rm -f "$refresh_log_file" "$diagnosis_file"
      exit 1
    fi
    latest_manifest_path="$output_dir/osiris-paperclip-runtime-latest.json"
    refresh_result_json_file="$(mktemp)"
    python3 - "$refresh_log_file" >"$refresh_result_json_file" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1]))
json.dump({"refresh_result": payload}, sys.stdout)
PY
    emit_json \
      "refresh_blocked_artifacts" \
      "blocked" \
      "Blocked on Paperclip auth. Refresh the canonical blocked-heartbeat artifacts and use the standalone blocked update payload." \
      "$latest_manifest_path" \
      "" \
      "" \
      "$refresh_result_json_file"
    rm -f "$refresh_result_json_file" "$refresh_log_file" "$diagnosis_file"
    exit 0
  fi
  if "$REFRESH_ARTIFACTS" "$output_dir" "$paperclip_secret_id" "$cursor_secret_id" >"$refresh_log_file"; then
    :
  else
    cat "$refresh_log_file" >&2
    rm -f "$refresh_log_file" "$diagnosis_file"
    exit 1
  fi
  latest_manifest_path="$output_dir/osiris-paperclip-runtime-latest.json"
  cat "$refresh_log_file"
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
  rm -f "$refresh_log_file" "$diagnosis_file"
  exit 0
fi

if [[ "$next_action_state" == "warn_session_only" ]]; then
  if [[ "$json_mode" == "1" ]]; then
    emit_json \
      "warn_session_only" \
      "session_only" \
      "Run visibility is available, but the Paperclip API helper is not ready. Inject PAPERCLIP_API_KEY and rerun this command." \
      ""
    rm -f "$diagnosis_file"
    exit 0
  fi
  cat <<EOF
Heartbeat disposition: run visibility available, but Paperclip API helper is not ready.
Run-scoped reads succeeded, but shell issue helpers still require PAPERCLIP_API_KEY.
Recommended next action: inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env, then rerun this command.
EOF
  rm -f "$diagnosis_file"
  exit 0
fi

playbook_text="$("$API_HELPER" current-issue-playbook)"
if [[ "$json_mode" == "1" ]]; then
  playbook_json_file="$(mktemp)"
  cat >"$playbook_json_file" <<'EOF'
{
  "playbook_commands": [
    "./scripts/paperclip-api.sh issue-get-current",
    "./scripts/paperclip-api.sh issue-comments-current",
    "./scripts/paperclip-api.sh issue-comment-current-template \"Resuming with auth fixed.\" true",
    "./scripts/paperclip-api.sh issue-blocked-current-template \"Paperclip operator\" \"Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env\" \"Current run is blocked.\"",
    "./scripts/paperclip-api.sh issue-update-current-template done \"Verified and complete.\""
  ]
}
EOF
  emit_json \
    "current_issue_playbook" \
    "ready" \
    "Issue operations are available via the Paperclip API helper. Follow the current-issue playbook." \
    "" \
    "$playbook_text" \
    "./scripts/paperclip-api.sh current-issue-playbook" \
    "$playbook_json_file"
  rm -f "$playbook_json_file" "$diagnosis_file"
  exit 0
fi

echo "Heartbeat disposition: issue operations available via API helper."
printf '%s\n' "$playbook_text"
rm -f "$diagnosis_file"
