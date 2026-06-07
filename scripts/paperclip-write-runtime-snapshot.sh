#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_CHECK="$ROOT_DIR/scripts/paperclip-runtime-check.sh"
API_HELPER="$ROOT_DIR/scripts/paperclip-api.sh"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-write-runtime-snapshot.sh OUTPUT_PATH [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]

Examples:
  ./scripts/paperclip-write-runtime-snapshot.sh reports/osiris-paperclip-runtime-snapshot.json
  ./scripts/paperclip-write-runtime-snapshot.sh \
    reports/osiris-paperclip-runtime-snapshot.json \
    osiris-paperclip-agent-key-secret-id \
    cursor-api-key-secret-id

Notes:
  - The snapshot captures the current runtime diagnosis as JSON plus the unblock payloads.
  - Non-zero runtime-check exits are preserved because blocked runs are expected here.
  - The helper creates the parent directory for OUTPUT_PATH when needed.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  usage
  exit 0
fi

output_path="${1:-}"
paperclip_secret_id="${2:-YOUR_PAPERCLIP_SECRET_ID}"
cursor_secret_id="${3:-YOUR_CURSOR_SECRET_ID}"

if [[ -z "$output_path" ]]; then
  echo "error: OUTPUT_PATH is required" >&2
  exit 2
fi

if [[ ! -x "$RUNTIME_CHECK" ]]; then
  echo "error: missing helper: $RUNTIME_CHECK" >&2
  exit 1
fi

if [[ ! -x "$API_HELPER" ]]; then
  echo "error: missing helper: $API_HELPER" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_path")"

runtime_json_file="$(mktemp)"
blocked_payload_file="$(mktemp)"
adapter_env_file="$(mktemp)"

runtime_status=0
if "$RUNTIME_CHECK" --json >"$runtime_json_file"; then
  runtime_status=0
else
  runtime_status=$?
fi

"$API_HELPER" blocked-template \
  "Paperclip operator" \
  "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
  "Current Cursor Cloud shell has no board-authenticated Paperclip session and no injected PAPERCLIP_API_KEY. After the env change, rerun the heartbeat and continue the current issue with resume=true." \
  >"$blocked_payload_file"

"$API_HELPER" adapter-env-template "$paperclip_secret_id" "$cursor_secret_id" >"$adapter_env_file"

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
branch_name="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
commit_sha="$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"

python3 - "$runtime_json_file" "$blocked_payload_file" "$adapter_env_file" "$timestamp" "$branch_name" "$commit_sha" "$runtime_status" >"$output_path" <<'PY'
import json
import sys
from pathlib import Path

runtime = json.loads(Path(sys.argv[1]).read_text())
blocked_payload = json.loads(Path(sys.argv[2]).read_text())
adapter_env_payload = json.loads(Path(sys.argv[3]).read_text())
timestamp = sys.argv[4]
branch_name = sys.argv[5]
commit_sha = sys.argv[6]
runtime_status = int(sys.argv[7])

payload = {
    "schema_version": 1,
    "artifact_type": "paperclip_runtime_snapshot",
    "generated_at": timestamp,
    "git": {
        "branch": branch_name,
        "commit": commit_sha,
    },
    "runtime_check_exit_code": runtime_status,
    "runtime": runtime,
    "unblock": {
        "owner": "Paperclip operator",
        "required_action": "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env",
        "blocked_issue_payload": blocked_payload,
        "adapter_env_payload": adapter_env_payload,
        "replay_commands": [
            "./scripts/paperclip-runtime-check.sh",
            "./scripts/paperclip-api.sh current-issue-playbook",
            './scripts/paperclip-api.sh issue-comment-current-template "Resuming with Cursor Cloud Paperclip auth fixed." true',
        ],
    },
}

json.dump(payload, sys.stdout, indent=2)
sys.stdout.write("\n")
PY

rm -f "$runtime_json_file" "$blocked_payload_file" "$adapter_env_file"

printf 'Wrote %s\n' "$output_path"
