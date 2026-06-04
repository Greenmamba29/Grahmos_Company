#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-api.sh health
  ./scripts/paperclip-api.sh session
  ./scripts/paperclip-api.sh current-run-issues
  ./scripts/paperclip-api.sh me
  ./scripts/paperclip-api.sh inbox-lite
  ./scripts/paperclip-api.sh current-issue-id
  ./scripts/paperclip-api.sh issue-get ISSUE_ID
  ./scripts/paperclip-api.sh issue-get-current
  ./scripts/paperclip-api.sh issue-comments ISSUE_ID [AFTER_COMMENT_ID]
  ./scripts/paperclip-api.sh issue-comments-current [AFTER_COMMENT_ID]
  ./scripts/paperclip-api.sh issue-comment ISSUE_ID JSON_FILE|-
  ./scripts/paperclip-api.sh issue-comment-current JSON_FILE|-
  ./scripts/paperclip-api.sh issue-interaction ISSUE_ID JSON_FILE|-
  ./scripts/paperclip-api.sh issue-interaction-current JSON_FILE|-
  ./scripts/paperclip-api.sh issue-update ISSUE_ID JSON_FILE|-
  ./scripts/paperclip-api.sh issue-update-current JSON_FILE|-
  ./scripts/paperclip-api.sh issue-blocked ISSUE_ID UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]
  ./scripts/paperclip-api.sh issue-blocked-current UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]

Examples:
  ./scripts/paperclip-api.sh health
  ./scripts/paperclip-api.sh session
  ./scripts/paperclip-api.sh current-run-issues
  ./scripts/paperclip-api.sh me
  ./scripts/paperclip-api.sh inbox-lite
  ./scripts/paperclip-api.sh current-issue-id
  ./scripts/paperclip-api.sh issue-get 123e4567-e89b-12d3-a456-426614174000
  ./scripts/paperclip-api.sh issue-get-current
  ./scripts/paperclip-api.sh issue-comments 123e4567-e89b-12d3-a456-426614174000
  ./scripts/paperclip-api.sh issue-comments-current
  printf '{"body":"Work started.","resume":true}\n' | \
    ./scripts/paperclip-api.sh issue-comment 123e4567-e89b-12d3-a456-426614174000 -
  ./scripts/paperclip-api.sh issue-interaction 123e4567-e89b-12d3-a456-426614174000 interaction.json
  ./scripts/paperclip-api.sh issue-update 123e4567-e89b-12d3-a456-426614174000 payload.json
  ./scripts/paperclip-api.sh issue-update-current payload.json
  ./scripts/paperclip-api.sh issue-blocked \
    123e4567-e89b-12d3-a456-426614174000 \
    "Paperclip operator" \
    "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
    "The runtime currently cannot mutate issue state."
  ./scripts/paperclip-api.sh issue-blocked-current \
    "Paperclip operator" \
    "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
    "Uses PAPERCLIP_TASK_ID when present, otherwise requires a single-item inbox."
  printf '{"comment":"Resuming with runtime auth fixed.","resume":true}\n' | \
    ./scripts/paperclip-api.sh issue-update 123e4567-e89b-12d3-a456-426614174000 -

Notes:
  - The script expects PAPERCLIP_API_URL for all commands.
  - `session` checks whether the current shell has a board-authenticated session.
  - `current-run-issues` uses `PAPERCLIP_RUN_ID` to query the run-bound issue list.
  - Issue and agent commands require PAPERCLIP_API_KEY.
  - Comment and interaction helpers accept the raw JSON body expected by the API.
  - Mutating commands automatically send X-Paperclip-Run-Id when PAPERCLIP_RUN_ID is present.
EOF
}

require_api_url() {
  if [[ -z "${PAPERCLIP_API_URL:-}" ]]; then
    echo "error: PAPERCLIP_API_URL is required" >&2
    exit 2
  fi
}

require_auth() {
  if [[ -z "${PAPERCLIP_API_KEY:-}" ]]; then
    echo "error: PAPERCLIP_API_KEY is required for this command" >&2
    exit 3
  fi
}

print_json() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json, sys
data = sys.stdin.read()
try:
    parsed = json.loads(data)
except Exception:
    sys.stdout.write(data)
else:
    json.dump(parsed, sys.stdout, indent=2)
    sys.stdout.write("\n")'
  else
    cat
  fi
}

request() {
  local method="$1"
  local path="$2"
  local body_file="${3:-}"

  require_api_url

  local -a args
  args=(-sSL -X "$method" -H "Accept: application/json")

  if [[ -n "${PAPERCLIP_API_KEY:-}" ]]; then
    args+=(-H "Authorization: Bearer $PAPERCLIP_API_KEY")
  fi

  if [[ "$method" != "GET" && -n "${PAPERCLIP_RUN_ID:-}" ]]; then
    args+=(-H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID")
  fi

  if [[ -n "$body_file" ]]; then
    args+=(-H "Content-Type: application/json" --data-binary "@$body_file")
  fi

  local tmp_body
  tmp_body="$(mktemp)"
  local code
  code="$(curl "${args[@]}" -o "$tmp_body" -w '%{http_code}' "$PAPERCLIP_API_URL$path")"

  if [[ "$code" -lt 200 || "$code" -ge 300 ]]; then
    echo "HTTP $code" >&2
    cat "$tmp_body" >&2
    rm -f "$tmp_body"
    exit 1
  fi

  cat "$tmp_body" | print_json
  rm -f "$tmp_body"
}

read_body_file() {
  local source="$1"
  local tmp_body
  tmp_body="$(mktemp)"

  if [[ "$source" == "-" ]]; then
    cat > "$tmp_body"
  else
    cp "$source" "$tmp_body"
  fi

  printf '%s\n' "$tmp_body"
}

resolve_single_issue_id_from_file() {
  local source_file="$1"
  local source_name="$2"

  python3 - "$source_file" "$source_name" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
source_name = sys.argv[2]
items = data if isinstance(data, list) else data.get("items", [])

if not items:
    print(f"error: {source_name} returned no issues", file=sys.stderr)
    raise SystemExit(4)

if len(items) > 1:
    print(f"error: multiple issues in {source_name}; pass ISSUE_ID explicitly", file=sys.stderr)
    for item in items:
        ident = item.get("identifier") or item.get("id")
        title = item.get("title") or ""
        print(f"- {ident}: {title}", file=sys.stderr)
    raise SystemExit(5)

issue_id = items[0].get("id")
if not issue_id:
    print(f"error: {source_name} item did not include an id", file=sys.stderr)
    raise SystemExit(6)

print(issue_id)
PY
}

request_current_run_issues() {
  require_api_url

  if [[ -z "${PAPERCLIP_RUN_ID:-}" ]]; then
    echo "error: PAPERCLIP_RUN_ID is required" >&2
    exit 2
  fi

  request GET "/api/heartbeat-runs/$PAPERCLIP_RUN_ID/issues"
}

write_blocked_payload() {
  local unblock_owner="$1"
  local required_action="$2"
  local details="${3:-}"
  local tmp_body
  tmp_body="$(mktemp)"

  python3 - "$unblock_owner" "$required_action" "$details" > "$tmp_body" <<'PY'
import json
import sys

owner = sys.argv[1].strip()
action = sys.argv[2].strip()
details = sys.argv[3].strip()

comment = f"Blocked.\n\nUnblock owner: {owner}\nRequired action: {action}"
if details:
    comment += f"\n\nDetails: {details}"

json.dump(
    {
        "status": "blocked",
        "comment": comment,
    },
    sys.stdout,
)
sys.stdout.write("\n")
PY

  printf '%s\n' "$tmp_body"
}

resolve_current_issue_id() {
  if [[ -n "${PAPERCLIP_TASK_ID:-}" ]]; then
    printf '%s\n' "$PAPERCLIP_TASK_ID"
    return 0
  fi

  require_api_url

  if [[ -n "${PAPERCLIP_RUN_ID:-}" ]]; then
    local run_body
    run_body="$(mktemp)"
    local run_code
    run_code="$(curl -sSL \
      -H "Accept: application/json" \
      -o "$run_body" \
      -w '%{http_code}' \
      "$PAPERCLIP_API_URL/api/heartbeat-runs/$PAPERCLIP_RUN_ID/issues")"

    if [[ "$run_code" -ge 200 && "$run_code" -lt 300 ]]; then
      resolve_single_issue_id_from_file "$run_body" "heartbeat-runs/$PAPERCLIP_RUN_ID/issues"
      rm -f "$run_body"
      return 0
    fi

    rm -f "$run_body"
  fi

  require_auth

  local inbox_body
  inbox_body="$(mktemp)"
  local inbox_code
  inbox_code="$(curl -sSL \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
    -o "$inbox_body" \
    -w '%{http_code}' \
    "$PAPERCLIP_API_URL/api/agents/me/inbox-lite")"

  if [[ "$inbox_code" -lt 200 || "$inbox_code" -ge 300 ]]; then
    echo "HTTP $inbox_code" >&2
    cat "$inbox_body" >&2
    rm -f "$inbox_body"
    exit 1
  fi

  resolve_single_issue_id_from_file "$inbox_body" "inbox-lite"
  rm -f "$inbox_body"
}

cmd="${1:-}"
case "$cmd" in
  health)
    request GET /api/health
    ;;
  session)
    request GET /api/auth/get-session
    ;;
  current-run-issues)
    request_current_run_issues
    ;;
  me)
    require_auth
    request GET /api/agents/me
    ;;
  inbox-lite)
    require_auth
    request GET /api/agents/me/inbox-lite
    ;;
  current-issue-id)
    resolve_current_issue_id
    ;;
  issue-get)
    require_auth
    issue_id="${2:-}"
    if [[ -z "$issue_id" ]]; then
      echo "error: ISSUE_ID is required" >&2
      exit 2
    fi
    request GET "/api/issues/$issue_id"
    ;;
  issue-get-current)
    require_auth
    issue_id="$(resolve_current_issue_id)"
    request GET "/api/issues/$issue_id"
    ;;
  issue-comments)
    require_auth
    issue_id="${2:-}"
    after_comment_id="${3:-}"
    if [[ -z "$issue_id" ]]; then
      echo "error: ISSUE_ID is required" >&2
      exit 2
    fi
    path="/api/issues/$issue_id/comments"
    if [[ -n "$after_comment_id" ]]; then
      path="$path?after=$after_comment_id&order=asc"
    fi
    request GET "$path"
    ;;
  issue-comments-current)
    require_auth
    after_comment_id="${2:-}"
    issue_id="$(resolve_current_issue_id)"
    path="/api/issues/$issue_id/comments"
    if [[ -n "$after_comment_id" ]]; then
      path="$path?after=$after_comment_id&order=asc"
    fi
    request GET "$path"
    ;;
  issue-comment)
    require_auth
    issue_id="${2:-}"
    source="${3:-}"
    if [[ -z "$issue_id" || -z "$source" ]]; then
      echo "error: ISSUE_ID and JSON_FILE|- are required" >&2
      exit 2
    fi
    body_file="$(read_body_file "$source")"
    request POST "/api/issues/$issue_id/comments" "$body_file"
    rm -f "$body_file"
    ;;
  issue-comment-current)
    require_auth
    source="${2:-}"
    if [[ -z "$source" ]]; then
      echo "error: JSON_FILE|- is required" >&2
      exit 2
    fi
    issue_id="$(resolve_current_issue_id)"
    body_file="$(read_body_file "$source")"
    request POST "/api/issues/$issue_id/comments" "$body_file"
    rm -f "$body_file"
    ;;
  issue-interaction)
    require_auth
    issue_id="${2:-}"
    source="${3:-}"
    if [[ -z "$issue_id" || -z "$source" ]]; then
      echo "error: ISSUE_ID and JSON_FILE|- are required" >&2
      exit 2
    fi
    body_file="$(read_body_file "$source")"
    request POST "/api/issues/$issue_id/interactions" "$body_file"
    rm -f "$body_file"
    ;;
  issue-interaction-current)
    require_auth
    source="${2:-}"
    if [[ -z "$source" ]]; then
      echo "error: JSON_FILE|- is required" >&2
      exit 2
    fi
    issue_id="$(resolve_current_issue_id)"
    body_file="$(read_body_file "$source")"
    request POST "/api/issues/$issue_id/interactions" "$body_file"
    rm -f "$body_file"
    ;;
  issue-update)
    require_auth
    issue_id="${2:-}"
    source="${3:-}"
    if [[ -z "$issue_id" || -z "$source" ]]; then
      echo "error: ISSUE_ID and JSON_FILE|- are required" >&2
      exit 2
    fi
    body_file="$(read_body_file "$source")"
    request PATCH "/api/issues/$issue_id" "$body_file"
    rm -f "$body_file"
    ;;
  issue-update-current)
    require_auth
    source="${2:-}"
    if [[ -z "$source" ]]; then
      echo "error: JSON_FILE|- is required" >&2
      exit 2
    fi
    issue_id="$(resolve_current_issue_id)"
    body_file="$(read_body_file "$source")"
    request PATCH "/api/issues/$issue_id" "$body_file"
    rm -f "$body_file"
    ;;
  issue-blocked)
    require_auth
    issue_id="${2:-}"
    unblock_owner="${3:-}"
    required_action="${4:-}"
    details="${5:-}"
    if [[ -z "$issue_id" || -z "$unblock_owner" || -z "$required_action" ]]; then
      echo "error: ISSUE_ID, UNBLOCK_OWNER, and REQUIRED_ACTION are required" >&2
      exit 2
    fi
    body_file="$(write_blocked_payload "$unblock_owner" "$required_action" "$details")"
    request PATCH "/api/issues/$issue_id" "$body_file"
    rm -f "$body_file"
    ;;
  issue-blocked-current)
    require_auth
    unblock_owner="${2:-}"
    required_action="${3:-}"
    details="${4:-}"
    if [[ -z "$unblock_owner" || -z "$required_action" ]]; then
      echo "error: UNBLOCK_OWNER and REQUIRED_ACTION are required" >&2
      exit 2
    fi
    issue_id="$(resolve_current_issue_id)"
    body_file="$(write_blocked_payload "$unblock_owner" "$required_action" "$details")"
    request PATCH "/api/issues/$issue_id" "$body_file"
    rm -f "$body_file"
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    echo "error: unknown command: $cmd" >&2
    echo >&2
    usage >&2
    exit 2
    ;;
esac
