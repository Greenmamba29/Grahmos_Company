#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  update-paperclip-issue.sh ISSUE_ID STATUS [--comment "text"] [--comment-file path]

Description:
  Update a Paperclip issue with a new status and optional comment using
  bearer-token authentication.

Environment:
  PAPERCLIP_API_URL          Required. Base URL for the Paperclip instance.
  PAPERCLIP_RUN_ID           Required. Current heartbeat run ID.
  PAPERCLIP_API_KEY          Optional if PAPERCLIP_API_KEY_FILE is set.
  PAPERCLIP_API_KEY_FILE     Optional path to a file containing the API key.

Examples:
  update-paperclip-issue.sh GRA-97 done --comment "Review completed."
  update-paperclip-issue.sh GRA-40 blocked --comment-file reports/GRA-40.md
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage >&2
  exit 1
fi

ISSUE_ID="$1"
STATUS="$2"
shift 2

COMMENT=""
COMMENT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --comment)
      if [[ $# -lt 2 ]]; then
        echo "error: --comment requires a value" >&2
        exit 1
      fi
      COMMENT="${2:-}"
      shift 2
      ;;
    --comment-file)
      if [[ $# -lt 2 ]]; then
        echo "error: --comment-file requires a path" >&2
        exit 1
      fi
      COMMENT_FILE="${2:-}"
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

API_URL="${PAPERCLIP_API_URL:-}"
RUN_ID="${PAPERCLIP_RUN_ID:-}"
API_KEY="${PAPERCLIP_API_KEY:-}"
API_KEY_FILE="${PAPERCLIP_API_KEY_FILE:-}"

if [[ -z "$API_URL" ]]; then
  echo "error: PAPERCLIP_API_URL is required" >&2
  exit 1
fi

API_URL="${API_URL%/}"

if [[ -z "$RUN_ID" ]]; then
  echo "error: PAPERCLIP_RUN_ID is required" >&2
  exit 1
fi

if [[ -z "$API_KEY" && -n "$API_KEY_FILE" && -f "$API_KEY_FILE" ]]; then
  API_KEY="$(<"$API_KEY_FILE")"
fi

if [[ -z "$API_KEY" ]]; then
  echo "error: PAPERCLIP_API_KEY or PAPERCLIP_API_KEY_FILE is required" >&2
  exit 1
fi

if [[ -n "$COMMENT_FILE" ]]; then
  if [[ ! -f "$COMMENT_FILE" ]]; then
    echo "error: comment file not found: $COMMENT_FILE" >&2
    exit 1
  fi
  COMMENT="$(<"$COMMENT_FILE")"
elif [[ -z "$COMMENT" && ! -t 0 ]]; then
  COMMENT="$(cat)"
fi

PAYLOAD_FILE="$(mktemp)"
trap 'rm -f "$PAYLOAD_FILE"' EXIT

export STATUS COMMENT

python3 - <<'PY' >"$PAYLOAD_FILE"
import json
import os

payload = {
    "status": os.environ["STATUS"],
}

comment = os.environ.get("COMMENT", "")
if comment:
    payload["comment"] = comment

print(json.dumps(payload))
PY

curl -sS -X PATCH \
  -H "Authorization: Bearer $API_KEY" \
  -H "X-Paperclip-Run-Id: $RUN_ID" \
  -H "Content-Type: application/json" \
  "$API_URL/api/issues/$ISSUE_ID" \
  --data-binary @"$PAYLOAD_FILE"
echo
