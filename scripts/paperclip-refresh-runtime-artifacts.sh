#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_WRITER="$ROOT_DIR/scripts/paperclip-write-runtime-report.sh"
SNAPSHOT_WRITER="$ROOT_DIR/scripts/paperclip-write-runtime-snapshot.sh"
BLOCKED_WRITER="$ROOT_DIR/scripts/paperclip-write-blocked-update.sh"
VALIDATOR="$ROOT_DIR/scripts/paperclip-validate-artifacts.sh"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-refresh-runtime-artifacts.sh [--json] [OUTPUT_DIR] [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]

Examples:
  ./scripts/paperclip-refresh-runtime-artifacts.sh
  ./scripts/paperclip-refresh-runtime-artifacts.sh --json
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
    - osiris-paperclip-runtime-validation.json
    - osiris-paperclip-runtime-latest.json
  - Also writes timestamped archive copies under OUTPUT_DIR/history/<timestamp>/.
  - OUTPUT_DIR defaults to reports.
  - This is the single-command refresh path for blocked Paperclip heartbeats.
  - Add `--json` for a machine-readable refresh result.
  - The helper validates the refreshed artifact set before returning success.
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

if [[ ! -x "$VALIDATOR" ]]; then
  echo "error: missing helper: $VALIDATOR" >&2
  exit 1
fi

mkdir -p "$output_dir"

report_path="$output_dir/osiris-paperclip-runtime-report.md"
snapshot_path="$output_dir/osiris-paperclip-runtime-snapshot.json"
blocked_path="$output_dir/osiris-paperclip-blocked-update.json"
validation_path="$output_dir/osiris-paperclip-runtime-validation.json"
latest_manifest_path="$output_dir/osiris-paperclip-runtime-latest.json"
timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
archive_dir="$output_dir/history/$timestamp"
branch_name="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
commit_sha="$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"

mkdir -p "$archive_dir"

writer_log_file="$(mktemp)"
if "$REPORT_WRITER" "$report_path" "$paperclip_secret_id" "$cursor_secret_id" >>"$writer_log_file"; then
  :
else
  cat "$writer_log_file" >&2
  rm -f "$writer_log_file"
  exit 1
fi
if "$SNAPSHOT_WRITER" "$snapshot_path" "$paperclip_secret_id" "$cursor_secret_id" >>"$writer_log_file"; then
  :
else
  cat "$writer_log_file" >&2
  rm -f "$writer_log_file"
  exit 1
fi
if "$BLOCKED_WRITER" "$blocked_path" >>"$writer_log_file"; then
  :
else
  cat "$writer_log_file" >&2
  rm -f "$writer_log_file"
  exit 1
fi

cp "$report_path" "$archive_dir/$(basename "$report_path")"
cp "$snapshot_path" "$archive_dir/$(basename "$snapshot_path")"
cp "$blocked_path" "$archive_dir/$(basename "$blocked_path")"

python3 - "$ROOT_DIR" "$report_path" "$snapshot_path" "$blocked_path" "$archive_dir" "$latest_manifest_path" "$timestamp" "$branch_name" "$commit_sha" <<'PY'
import hashlib
import json
import os
import sys
from pathlib import Path

workspace_root = Path(sys.argv[1]).resolve()
report_path = Path(sys.argv[2]).resolve()
snapshot_path = Path(sys.argv[3]).resolve()
blocked_path = Path(sys.argv[4]).resolve()
archive_dir = Path(sys.argv[5]).resolve()
manifest_path = Path(sys.argv[6]).resolve()
timestamp = sys.argv[7]
branch_name = sys.argv[8]
commit_sha = sys.argv[9]

snapshot = json.loads(snapshot_path.read_text())
archive_report_path = archive_dir / report_path.name
archive_snapshot_path = archive_dir / snapshot_path.name
archive_blocked_path = archive_dir / blocked_path.name
archive_manifest_path = archive_dir / manifest_path.name

def rel(path: Path) -> str:
    return os.path.relpath(path, workspace_root)

def file_metadata(path: Path) -> dict:
    data = path.read_bytes()
    return {
        "path": str(path),
        "relative_path": rel(path),
        "size_bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }

manifest = {
    "schema_version": 1,
    "artifact_type": "paperclip_runtime_latest_manifest",
    "generated_at": timestamp,
    "workspace_root": str(workspace_root),
    "git": {
        "branch": branch_name,
        "commit": commit_sha,
    },
    "latest": {
        "report_path": str(report_path),
        "report_relative_path": rel(report_path),
        "snapshot_path": str(snapshot_path),
        "snapshot_relative_path": rel(snapshot_path),
        "blocked_update_path": str(blocked_path),
        "blocked_update_relative_path": rel(blocked_path),
        "latest_manifest_path": str(manifest_path),
        "latest_manifest_relative_path": rel(manifest_path),
        "latest_archive_dir": str(archive_dir),
        "latest_archive_dir_relative_path": rel(archive_dir),
        "archive_report_path": str(archive_report_path),
        "archive_report_relative_path": rel(archive_report_path),
        "archive_snapshot_path": str(archive_snapshot_path),
        "archive_snapshot_relative_path": rel(archive_snapshot_path),
        "archive_blocked_update_path": str(archive_blocked_path),
        "archive_blocked_update_relative_path": rel(archive_blocked_path),
        "archive_manifest_path": str(archive_manifest_path),
        "archive_manifest_relative_path": rel(archive_manifest_path),
    },
    "file_metadata": {
        "report": file_metadata(report_path),
        "snapshot": file_metadata(snapshot_path),
        "blocked_update": file_metadata(blocked_path),
        "archive_report": file_metadata(archive_report_path),
        "archive_snapshot": file_metadata(archive_snapshot_path),
        "archive_blocked_update": file_metadata(archive_blocked_path),
    },
    "runtime": {
        "diagnosis": snapshot.get("runtime", {}).get("diagnosis"),
        "heartbeat_next_action_state": snapshot.get("runtime", {}).get("heartbeat_next_action_state"),
        "issue_operations_blocked": snapshot.get("runtime", {}).get("issue_operations_blocked"),
    },
}

manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
PY

cp "$latest_manifest_path" "$archive_dir/$(basename "$latest_manifest_path")"

validation_json_file="$(mktemp)"
if "$VALIDATOR" --json "$output_dir" >"$validation_json_file"; then
  :
else
  cat "$validation_json_file" >&2
  rm -f "$writer_log_file" "$validation_json_file"
  exit 1
fi

cp "$validation_json_file" "$validation_path"
cp "$validation_path" "$archive_dir/$(basename "$validation_path")"

if [[ "$json_mode" == "1" ]]; then
  python3 - "$latest_manifest_path" "$output_dir" "$archive_dir" "$validation_json_file" "$validation_path" <<'PY'
import json
import sys

latest_manifest = json.load(open(sys.argv[1]))
validation_result = json.load(open(sys.argv[4]))
payload = {
    "schema_version": 1,
    "artifact_type": "paperclip_refresh_result",
    "output_dir": sys.argv[2],
    "archive_dir": sys.argv[3],
    "latest_manifest_path": sys.argv[1],
    "latest_manifest": latest_manifest,
    "validation_result": validation_result,
    "validation_artifact_path": sys.argv[5],
}
json.dump(payload, sys.stdout, indent=2)
sys.stdout.write("\n")
PY
  rm -f "$writer_log_file" "$validation_json_file"
  exit 0
fi

cat "$writer_log_file"
rm -f "$writer_log_file"
printf 'Refreshed runtime artifacts in %s\n' "$output_dir"
printf 'Archived runtime artifacts in %s\n' "$archive_dir"
printf 'Validated runtime artifacts in %s\n' "$output_dir"
rm -f "$validation_json_file"
