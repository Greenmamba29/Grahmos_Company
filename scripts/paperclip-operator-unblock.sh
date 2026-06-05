#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_HELPER="$ROOT_DIR/scripts/paperclip-api.sh"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-operator-unblock.sh [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]

Examples:
  ./scripts/paperclip-operator-unblock.sh \
    osiris-paperclip-agent-key-secret-id \
    cursor-api-key-secret-id

Notes:
  - When secret ids are omitted, the script prints placeholder ids.
  - The output includes:
    1. a blocked-issue status payload naming the unblock owner/action
    2. the Cursor Cloud adapter env JSON needed to inject PAPERCLIP_API_KEY
    3. the post-fix verification and replay commands for the next heartbeat
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  usage
  exit 0
fi

if [[ ! -x "$API_HELPER" ]]; then
  echo "error: missing helper: $API_HELPER" >&2
  exit 1
fi

paperclip_secret_id="${1:-YOUR_PAPERCLIP_SECRET_ID}"
cursor_secret_id="${2:-YOUR_CURSOR_SECRET_ID}"

cat <<EOF
Paperclip Cursor Cloud unblock handoff
======================================

Use this when ./scripts/paperclip-runtime-check.sh reports that:
- board authentication is unavailable in the shell
- PAPERCLIP_API_KEY is not present
- CLOUD_AGENT_INJECTED_SECRET_NAMES does not include PAPERCLIP_API_KEY

Blocked issue payload
---------------------
EOF

"$API_HELPER" blocked-template \
  "Paperclip operator" \
  "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
  "Current Cursor Cloud shell has no board-authenticated Paperclip session and no injected PAPERCLIP_API_KEY. After the env change, rerun the heartbeat and continue the current issue with resume=true."

cat <<EOF

Adapter env payload
-------------------
EOF

"$API_HELPER" adapter-env-template "$paperclip_secret_id" "$cursor_secret_id"

cat <<'EOF'

Replay commands after the adapter env update
--------------------------------------------
./scripts/paperclip-runtime-check.sh
./scripts/paperclip-api.sh current-issue-playbook

Recommended first issue update after auth is fixed
--------------------------------------------------
./scripts/paperclip-api.sh issue-comment-current-template "Resuming with Cursor Cloud Paperclip auth fixed." true
EOF
