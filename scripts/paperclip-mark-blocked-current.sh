#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

unblock_owner="${1:-Paperclip operator / Osiris Hermes}"
required_action="${2:-Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env so it appears in CLOUD_AGENT_INJECTED_SECRET_NAMES.}"

payload_file="$(mktemp)"
cleanup() {
  rm -f "$payload_file"
}
trap cleanup EXIT

"$script_dir/paperclip-blocked-payload.sh" "$unblock_owner" "$required_action" > "$payload_file"
issue_id="$("$script_dir/paperclip-api.sh" current-issue-id)"
"$script_dir/paperclip-api.sh" issue-update "$issue_id" "$payload_file"
