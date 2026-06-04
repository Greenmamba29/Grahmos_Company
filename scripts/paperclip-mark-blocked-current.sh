#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resume_comment="false"
args=()
for arg in "$@"; do
  if [[ "$arg" == "--resume" ]]; then
    resume_comment="true"
  else
    args+=("$arg")
  fi
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
issue_id="$("$script_dir/paperclip-api.sh" current-issue-id)"

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

"$script_dir/paperclip-api.sh" issue-comment "$issue_id" "$comment_file"
"$script_dir/paperclip-api.sh" issue-update "$issue_id" "$status_file"
