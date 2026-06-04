#!/usr/bin/env bash

set -euo pipefail

API_URL="${PAPERCLIP_API_URL:-}"
COOKIE_JAR=""
ISSUE_ID=""
OWNER="Paperclip board admin/operator"
ACTION="Provide a supported authenticated automation path for cloud agents (browser session, MCP, or documented API auth)."
REASON="Cloud-agent shell requests cannot update Paperclip issues because the instance requires board-authenticated session access."
RESUME=0
DRY_RUN=0
SHOW_HELP=0
EVIDENCE=()

usage() {
  cat <<'EOF'
Usage: paperclip-send-blocked-update.sh --issue-id ISSUE_ID --cookie-jar PATH [options]

Posts a blocked-status task comment and then PATCHes the issue status to blocked.
This script requires a valid authenticated Paperclip cookie jar.

Options:
  --issue-id ID         Paperclip issue UUID or identifier.
  --cookie-jar PATH     Cookie jar file for authenticated curl requests.
  --owner TEXT          Named unblock owner for the generated task comment.
  --action TEXT         Named unblock action for the generated task comment.
  --reason TEXT         Short blocked reason for the generated task comment.
  --evidence TEXT       Evidence bullet to include in the generated comment. Repeatable.
  --resume              Include resume=true in both generated payloads.
  --dry-run             Generate payloads and print the requests without sending them.
  -h, --help            Show this help text.
EOF
}

while (($# > 0)); do
  case "$1" in
    --issue-id)
      ISSUE_ID="${2:-}"
      shift 2
      ;;
    --cookie-jar)
      COOKIE_JAR="${2:-}"
      shift 2
      ;;
    --owner)
      OWNER="${2:-}"
      shift 2
      ;;
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --reason)
      REASON="${2:-}"
      shift 2
      ;;
    --evidence)
      EVIDENCE+=("${2:-}")
      shift 2
      ;;
    --resume)
      RESUME=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      SHOW_HELP=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$SHOW_HELP" -eq 1 ]]; then
  usage
  exit 0
fi

if [[ -z "$API_URL" ]]; then
  echo "PAPERCLIP_API_URL is required in the environment." >&2
  exit 2
fi

if [[ -z "$ISSUE_ID" || -z "$COOKIE_JAR" ]]; then
  echo "--issue-id and --cookie-jar are required." >&2
  usage >&2
  exit 2
fi

if [[ ! -f "$COOKIE_JAR" ]]; then
  echo "Cookie jar not found: $COOKIE_JAR" >&2
  exit 2
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HELPER_ARGS=(
  python3 /workspace/scripts/paperclip-blocked-update-helper.py
  "$ISSUE_ID"
  --owner "$OWNER"
  --action "$ACTION"
  --reason "$REASON"
  --write-dir "$TMP_DIR"
)

if [[ "$RESUME" -eq 1 ]]; then
  HELPER_ARGS+=(--resume)
fi

for item in "${EVIDENCE[@]}"; do
  HELPER_ARGS+=(--evidence "$item")
done

"${HELPER_ARGS[@]}" >/dev/null

COMMENT_PAYLOAD="$TMP_DIR/paperclip-comment-payload.json"
STATUS_PAYLOAD="$TMP_DIR/paperclip-status-payload.json"
COMMENT_URL="${API_URL%/}/api/issues/${ISSUE_ID}/comments"
STATUS_URL="${API_URL%/}/api/issues/${ISSUE_ID}"

echo "Paperclip blocked update sender"
echo "  issue_id: $ISSUE_ID"
echo "  cookie_jar: $COOKIE_JAR"
echo "  comment_url: $COMMENT_URL"
echo "  status_url: $STATUS_URL"
echo

echo "Comment payload:"
sed 's/^/  /' "$COMMENT_PAYLOAD"
echo
echo "Status payload:"
sed 's/^/  /' "$STATUS_PAYLOAD"
echo

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run only; no requests were sent."
  exit 0
fi

echo "Sending task comment..."
curl -sS -X POST "$COMMENT_URL" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  --data @"$COMMENT_PAYLOAD"
echo
echo

echo "Sending status update..."
curl -sS -X PATCH "$STATUS_URL" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  --data @"$STATUS_PAYLOAD"
echo
