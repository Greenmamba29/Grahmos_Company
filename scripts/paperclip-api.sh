#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-api.sh health
  ./scripts/paperclip-api.sh sample-payload TYPE
  ./scripts/paperclip-api.sh session
  ./scripts/paperclip-api.sh me
  ./scripts/paperclip-api.sh inbox-lite
  ./scripts/paperclip-api.sh current-issue-id
  ./scripts/paperclip-api.sh issue-get ISSUE_ID
  ./scripts/paperclip-api.sh issue-comments ISSUE_ID [AFTER_COMMENT_ID]
  ./scripts/paperclip-api.sh issue-comment ISSUE_ID JSON_FILE|-
  ./scripts/paperclip-api.sh issue-comment-current JSON_FILE|-
  ./scripts/paperclip-api.sh issue-update ISSUE_ID JSON_FILE|-
  ./scripts/paperclip-api.sh issue-update-current JSON_FILE|-
  ./scripts/paperclip-api.sh issue-interaction ISSUE_ID JSON_FILE|-
  ./scripts/paperclip-api.sh issue-interaction-current JSON_FILE|-
  ./scripts/paperclip-api.sh issue-blocked ISSUE_ID UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]
  ./scripts/paperclip-api.sh issue-blocked-current UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]

Examples:
  ./scripts/paperclip-api.sh sample-payload comment-resume
  ./scripts/paperclip-api.sh sample-payload request-confirmation
  ./scripts/paperclip-api.sh health
  ./scripts/paperclip-api.sh session
  ./scripts/paperclip-api.sh me
  ./scripts/paperclip-api.sh inbox-lite
  ./scripts/paperclip-api.sh current-issue-id
  ./scripts/paperclip-api.sh issue-get 123e4567-e89b-12d3-a456-426614174000
  ./scripts/paperclip-api.sh issue-comments 123e4567-e89b-12d3-a456-426614174000
  printf '{"body":"Work started.","resume":true}\n' | \
    ./scripts/paperclip-api.sh issue-comment 123e4567-e89b-12d3-a456-426614174000 -
  printf '{"status":"done","comment":"Verified and finished."}\n' | \
    ./scripts/paperclip-api.sh issue-update-current -
  printf '{"kind":"ask_user_questions","title":"Need board input"}\n' | \
    ./scripts/paperclip-api.sh issue-interaction-current -
  ./scripts/paperclip-api.sh issue-update 123e4567-e89b-12d3-a456-426614174000 payload.json
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
  - `sample-payload` prints valid JSON examples for common comment, update, and interaction requests.
  - `session` checks whether the current shell has a board-authenticated session.
  - Issue and agent commands require PAPERCLIP_API_KEY.
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

sample_payload() {
  local kind="${1:-}"

  case "$kind" in
    comment-resume)
      cat <<'EOF'
{
  "body": "Resuming work in this heartbeat.",
  "resume": true
}
EOF
      ;;
    update-done)
      cat <<'EOF'
{
  "status": "done",
  "comment": "Completed and verified."
}
EOF
      ;;
    update-blocked)
      cat <<'EOF'
{
  "status": "blocked",
  "comment": "Blocked.\n\nUnblock owner: Paperclip operator\nRequired action: Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter environment."
}
EOF
      ;;
    suggest-tasks)
      cat <<'EOF'
{
  "kind": "suggest_tasks",
  "title": "Suggested follow-up tasks",
  "summary": "Choose the tasks that should be created from this issue.",
  "continuationPolicy": "wake_assignee",
  "payload": {
    "version": 1,
    "tasks": [
      {
        "clientKey": "task-1",
        "title": "First follow-up task"
      },
      {
        "clientKey": "task-2",
        "title": "Second follow-up task"
      }
    ]
  }
}
EOF
      ;;
    ask-user-questions)
      cat <<'EOF'
{
  "kind": "ask_user_questions",
  "title": "Need user input",
  "summary": "Choose one of the following options so work can continue.",
  "continuationPolicy": "wake_assignee",
  "payload": {
    "version": 1,
    "title": "Question for the board/user",
    "submitLabel": "Submit answers",
    "questions": [
      {
        "id": "next-step",
        "prompt": "Which path should we take next?",
        "selectionMode": "single",
        "required": true,
        "options": [
          {
            "id": "option-a",
            "label": "Option A"
          },
          {
            "id": "option-b",
            "label": "Option B"
          }
        ]
      }
    ]
  }
}
EOF
      ;;
    request-confirmation)
      cat <<'EOF'
{
  "kind": "request_confirmation",
  "idempotencyKey": "confirmation:issue-id:plan:revision-id",
  "title": "Plan approval required",
  "summary": "Review the attached plan revision and approve or reject it.",
  "continuationPolicy": "wake_assignee_on_accept",
  "payload": {
    "version": 1,
    "prompt": "Approve the latest plan revision so implementation can begin?",
    "acceptLabel": "Approve plan",
    "rejectLabel": "Request changes",
    "rejectRequiresReason": true,
    "rejectReasonLabel": "What should change?",
    "detailsMarkdown": "This confirmation should target the latest plan revision.",
    "supersedeOnUserComment": true,
    "target": {
      "type": "custom",
      "key": "plan",
      "revisionId": "revision-id"
    }
  }
}
EOF
      ;;
    ""|-h|--help|help)
      cat <<'EOF'
Supported sample payload types:
  comment-resume
  update-done
  update-blocked
  suggest-tasks
  ask-user-questions
  request-confirmation
EOF
      ;;
    *)
      echo "error: unknown sample payload type: $kind" >&2
      exit 2
      ;;
  esac
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

  require_auth
  require_api_url

  local tmp_body
  tmp_body="$(mktemp)"
  local code
  code="$(curl -sSL \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
    -o "$tmp_body" \
    -w '%{http_code}' \
    "$PAPERCLIP_API_URL/api/agents/me/inbox-lite")"

  if [[ "$code" -lt 200 || "$code" -ge 300 ]]; then
    echo "HTTP $code" >&2
    cat "$tmp_body" >&2
    rm -f "$tmp_body"
    exit 1
  fi

  python3 - "$tmp_body" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
items = data if isinstance(data, list) else data.get("items", [])

if not items:
    print("error: inbox-lite returned no issues and PAPERCLIP_TASK_ID is not set", file=sys.stderr)
    raise SystemExit(4)

if len(items) > 1:
    print("error: multiple issues in inbox-lite; pass ISSUE_ID explicitly", file=sys.stderr)
    for item in items:
        ident = item.get("identifier") or item.get("id")
        title = item.get("title") or ""
        print(f"- {ident}: {title}", file=sys.stderr)
    raise SystemExit(5)

issue_id = items[0].get("id")
if not issue_id:
    print("error: inbox-lite item did not include an id", file=sys.stderr)
    raise SystemExit(6)

print(issue_id)
PY

  rm -f "$tmp_body"
}

cmd="${1:-}"
case "$cmd" in
  health)
    request GET /api/health
    ;;
  sample-payload)
    sample_payload "${2:-}"
    ;;
  session)
    request GET /api/auth/get-session
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
