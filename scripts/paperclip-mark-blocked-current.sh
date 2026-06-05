#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resume_comment="false"
dry_run="false"
issue_id=""
issue_query=""
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resume)
      resume_comment="true"
      shift
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --issue-id)
      if [[ $# -lt 2 ]]; then
        echo "error: --issue-id requires a value" >&2
        exit 2
      fi
      issue_id="$2"
      shift 2
      ;;
    --query)
      if [[ $# -lt 2 ]]; then
        echo "error: --query requires a value" >&2
        exit 2
      fi
      issue_query="$2"
      shift 2
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        args+=("$1")
        shift
      done
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

unblock_owner="${args[0]:-Paperclip operator / Osiris Hermes}"
required_action="${args[1]:-Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env so it appears in CLOUD_AGENT_INJECTED_SECRET_NAMES.}"

payload_file="$(mktemp)"
comment_file="$(mktemp)"
status_file="$(mktemp)"
cleanup() {
  rm -f "$payload_file" "$comment_file" "$status_file"
}
trap cleanup EXIT

"$script_dir/paperclip-blocked-payload.sh" "$unblock_owner" "$required_action" > "$payload_file"
if [[ -z "$issue_id" ]]; then
  if [[ -n "$issue_query" ]]; then
    issue_id="$("$script_dir/paperclip-api.sh" issues-single-id "$issue_query")"
  else
    issue_id="$("$script_dir/paperclip-api.sh" current-issue-id)"
  fi
fi

python3 - "$payload_file" "$comment_file" "$status_file" "$resume_comment" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text())
comment = payload.get("comment", "")
status = payload.get("status", "blocked")
resume_comment = sys.argv[4].strip().lower() == "true"

comment_payload = {"body": comment}
if resume_comment:
    comment_payload["resume"] = True

Path(sys.argv[2]).write_text(json.dumps(comment_payload, indent=2) + "\n")
Path(sys.argv[3]).write_text(json.dumps({"status": status}, indent=2) + "\n")
PY

if [[ "$dry_run" == "true" ]]; then
  python3 - "$issue_id" "$comment_file" "$status_file" <<'PY'
import json
import sys
from pathlib import Path

issue_id = sys.argv[1]
comment_payload = json.loads(Path(sys.argv[2]).read_text())
status_payload = json.loads(Path(sys.argv[3]).read_text())

json.dump(
    {
        "issueId": issue_id,
        "commentPayload": comment_payload,
        "statusPayload": status_payload,
    },
    sys.stdout,
    indent=2,
)
sys.stdout.write("\n")
PY
  exit 0
fi

"$script_dir/paperclip-api.sh" issue-comment "$issue_id" "$comment_file"
"$script_dir/paperclip-api.sh" issue-update "$issue_id" "$status_file"
