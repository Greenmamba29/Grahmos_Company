#!/usr/bin/env bash

set -euo pipefail

ISSUE_ID=""
COOKIE_JAR=""
OWNER="Paperclip board admin/operator"
ACTION="Provide a supported authenticated automation path for cloud agents (browser session, MCP, or documented API auth)."
REASON="Cloud-agent shell requests cannot update Paperclip issues because the instance requires board-authenticated session access."
DRY_RUN=0
RESUME=0
EVIDENCE=()

usage() {
  cat <<'EOF'
Usage: paperclip-finalize-blocked.sh --issue-id ISSUE_ID --cookie-jar PATH [options]

Runs the Paperclip auth probe and, if authenticated, sends the blocked comment
and status update automatically.

Exit codes:
  0  Authenticated and update sent (or dry-run sender completed)
  2  Invalid arguments or local setup issue
  3  Blocked: board authentication still missing
  4  Unknown auth state

Options:
  --issue-id ID         Paperclip issue UUID or identifier.
  --cookie-jar PATH     Cookie jar file for authenticated curl requests.
  --owner TEXT          Named unblock owner for the task comment.
  --action TEXT         Named unblock action for the task comment.
  --reason TEXT         Short blocked reason for the task comment.
  --evidence TEXT       Evidence bullet to include in the task comment. Repeatable.
  --resume              Include resume=true in generated payloads.
  --dry-run             Stop after assembling and printing the requests.
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
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ISSUE_ID" || -z "$COOKIE_JAR" ]]; then
  echo "--issue-id and --cookie-jar are required." >&2
  usage >&2
  exit 2
fi

if [[ ! -f "$COOKIE_JAR" ]]; then
  echo "Cookie jar not found: $COOKIE_JAR" >&2
  exit 2
fi

echo "Running auth probe..."
set +e
/workspace/scripts/paperclip-auth-probe.sh --cookie-jar "$COOKIE_JAR"
probe_status=$?
set -e

case "$probe_status" in
  0)
    echo
    echo "Auth probe succeeded. Sending blocked update..."
    ;;
  3)
    echo
    echo "Blocked update not sent because board authentication is still missing." >&2
    exit 3
    ;;
  4)
    echo
    echo "Blocked update not sent because auth state is unknown." >&2
    exit 4
    ;;
  *)
    echo
    echo "Blocked update not sent because the auth probe failed unexpectedly (exit $probe_status)." >&2
    exit "$probe_status"
    ;;
esac

sender_args=(
  /workspace/scripts/paperclip-send-blocked-update.sh
  --issue-id "$ISSUE_ID"
  --cookie-jar "$COOKIE_JAR"
  --owner "$OWNER"
  --action "$ACTION"
  --reason "$REASON"
)

if [[ "$RESUME" -eq 1 ]]; then
  sender_args+=(--resume)
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  sender_args+=(--dry-run)
fi

for item in "${EVIDENCE[@]}"; do
  sender_args+=(--evidence "$item")
done

"${sender_args[@]}"
