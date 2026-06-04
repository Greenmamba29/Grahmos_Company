#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-api.sh health
  ./scripts/paperclip-api.sh session
  ./scripts/paperclip-api.sh me
  ./scripts/paperclip-api.sh inbox-lite
  ./scripts/paperclip-api.sh adapter-env-template PAPERCLIP_SECRET_ID [CURSOR_SECRET_ID]
  ./scripts/paperclip-api.sh comment-template BODY [RESUME_TRUE_OR_FALSE]
  ./scripts/paperclip-api.sh update-template STATUS COMMENT [RESUME_TRUE_OR_FALSE]
  ./scripts/paperclip-api.sh blocked-template UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]
  ./scripts/paperclip-api.sh interaction-template KIND TITLE [JSON_FILE|-]
  ./scripts/paperclip-api.sh current-issue-id
  ./scripts/paperclip-api.sh issue-get ISSUE_ID
  ./scripts/paperclip-api.sh issue-get-current
  ./scripts/paperclip-api.sh issue-comments ISSUE_ID [AFTER_COMMENT_ID]
  ./scripts/paperclip-api.sh issue-comments-current [AFTER_COMMENT_ID]
  ./scripts/paperclip-api.sh issue-comment ISSUE_ID JSON_FILE|-
  ./scripts/paperclip-api.sh issue-comment-current JSON_FILE|-
  ./scripts/paperclip-api.sh issue-comment-current-template BODY [RESUME_TRUE_OR_FALSE]
  ./scripts/paperclip-api.sh issue-interaction ISSUE_ID JSON_FILE|-
  ./scripts/paperclip-api.sh issue-interaction-current JSON_FILE|-
  ./scripts/paperclip-api.sh issue-interaction-current-template KIND TITLE [JSON_FILE|-]
  ./scripts/paperclip-api.sh issue-update ISSUE_ID JSON_FILE|-
  ./scripts/paperclip-api.sh issue-update-current JSON_FILE|-
  ./scripts/paperclip-api.sh issue-update-current-template STATUS COMMENT [RESUME_TRUE_OR_FALSE]
  ./scripts/paperclip-api.sh issue-blocked ISSUE_ID UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]
  ./scripts/paperclip-api.sh issue-blocked-current UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]
  ./scripts/paperclip-api.sh issue-blocked-current-template UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]

Examples:
  ./scripts/paperclip-api.sh health
  ./scripts/paperclip-api.sh session
  ./scripts/paperclip-api.sh me
  ./scripts/paperclip-api.sh inbox-lite
  ./scripts/paperclip-api.sh adapter-env-template \
    osiris-paperclip-agent-key-secret-id \
    cursor-api-key-secret-id
  ./scripts/paperclip-api.sh comment-template "Resuming with auth fixed." true
  ./scripts/paperclip-api.sh update-template done "Verified and complete."
  ./scripts/paperclip-api.sh blocked-template \
    "Paperclip operator" \
    "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
    "The runtime currently cannot mutate issue state."
  printf '{"questions":[{"id":"auth","label":"Should I inject PAPERCLIP_API_KEY next?"}],"continuationPolicy":"wake_assignee"}\n' | \
    ./scripts/paperclip-api.sh interaction-template ask_user_questions "Need input" -
  ./scripts/paperclip-api.sh current-issue-id
  ./scripts/paperclip-api.sh issue-get 123e4567-e89b-12d3-a456-426614174000
  ./scripts/paperclip-api.sh issue-get-current
  ./scripts/paperclip-api.sh issue-comments 123e4567-e89b-12d3-a456-426614174000
  ./scripts/paperclip-api.sh issue-comments-current
  ./scripts/paperclip-api.sh issue-comment-current-template "Resuming with auth fixed." true
  printf '{"body":"Work started.","resume":true}\n' | \
    ./scripts/paperclip-api.sh issue-comment 123e4567-e89b-12d3-a456-426614174000 -
  printf '{"kind":"ask_user_questions","title":"Need input","questions":[{"id":"auth","label":"Should I inject PAPERCLIP_API_KEY next?"}],"continuationPolicy":"wake_assignee"}\n' | \
    ./scripts/paperclip-api.sh issue-interaction 123e4567-e89b-12d3-a456-426614174000 -
  printf '{"questions":[{"id":"auth","label":"Should I inject PAPERCLIP_API_KEY next?"}],"continuationPolicy":"wake_assignee"}\n' | \
    ./scripts/paperclip-api.sh issue-interaction-current-template ask_user_questions "Need input" -
  ./scripts/paperclip-api.sh issue-update 123e4567-e89b-12d3-a456-426614174000 payload.json
  ./scripts/paperclip-api.sh issue-update-current-template done "Verified and complete."
  ./scripts/paperclip-api.sh issue-blocked-current-template \
    "Paperclip operator" \
    "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env" \
    "The runtime currently cannot mutate issue state."
  printf '{"status":"done","comment":"Verified and complete."}\n' | \
    ./scripts/paperclip-api.sh issue-update-current -
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
  - Issue and agent commands require PAPERCLIP_API_KEY.
  - Mutating commands automatically send X-Paperclip-Run-Id when PAPERCLIP_RUN_ID is present.
  - `adapter-env-template` prints the JSON shape needed to inject PAPERCLIP_API_KEY
    into the Cursor Cloud adapter environment.
  - `comment-template`, `update-template`, and `blocked-template` print JSON payloads
    that can be piped into the current-issue mutation helpers.
  - `interaction-template` merges `kind` and `title` with optional extra JSON for
    ask_user_questions, suggest_tasks, or request_confirmation payloads.
  - `issue-*-current-template` commands generate the payload and immediately apply it
    to the current issue once auth is available.
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

print_adapter_env_template() {
  local paperclip_secret_id="${1:-}"
  local cursor_secret_id="${2:-}"

  if [[ -z "$paperclip_secret_id" ]]; then
    echo "error: PAPERCLIP_SECRET_ID is required" >&2
    exit 2
  fi

  python3 - "$paperclip_secret_id" "$cursor_secret_id" <<'PY'
import json
import sys

paperclip_secret_id = sys.argv[1].strip()
cursor_secret_id = sys.argv[2].strip()

env = {
    "PAPERCLIP_API_KEY": {
        "type": "secret_ref",
        "secretId": paperclip_secret_id,
        "version": "latest",
    }
}

if cursor_secret_id:
    env["CURSOR_API_KEY"] = {
        "type": "secret_ref",
        "secretId": cursor_secret_id,
        "version": "latest",
    }

payload = {
    "adapterType": "cursor_cloud",
    "adapterConfig": {
        "env": env,
    },
}

json.dump(payload, sys.stdout, indent=2, sort_keys=True)
sys.stdout.write("\n")
PY
}

print_comment_template() {
  local body="${1:-}"
  local resume_flag="${2:-}"

  if [[ -z "$body" ]]; then
    echo "error: BODY is required" >&2
    exit 2
  fi

  python3 - "$body" "$resume_flag" <<'PY'
import json
import sys

body = sys.argv[1]
resume_flag = sys.argv[2].strip().lower()

payload = {"body": body}
if resume_flag:
    payload["resume"] = resume_flag in {"1", "true", "yes"}

json.dump(payload, sys.stdout, indent=2)
sys.stdout.write("\n")
PY
}

print_update_template() {
  local status="${1:-}"
  local comment="${2:-}"
  local resume_flag="${3:-}"

  if [[ -z "$status" || -z "$comment" ]]; then
    echo "error: STATUS and COMMENT are required" >&2
    exit 2
  fi

  python3 - "$status" "$comment" "$resume_flag" <<'PY'
import json
import sys

status = sys.argv[1]
comment = sys.argv[2]
resume_flag = sys.argv[3].strip().lower()

payload = {
    "status": status,
    "comment": comment,
}
if resume_flag:
    payload["resume"] = resume_flag in {"1", "true", "yes"}

json.dump(payload, sys.stdout, indent=2)
sys.stdout.write("\n")
PY
}

print_blocked_template() {
  local unblock_owner="${1:-}"
  local required_action="${2:-}"
  local details="${3:-}"
  local body_file

  if [[ -z "$unblock_owner" || -z "$required_action" ]]; then
    echo "error: UNBLOCK_OWNER and REQUIRED_ACTION are required" >&2
    exit 2
  fi

  body_file="$(write_blocked_payload "$unblock_owner" "$required_action" "$details")"
  print_json < "$body_file"
  rm -f "$body_file"
}

print_interaction_template() {
  local kind="${1:-}"
  local title="${2:-}"
  local source="${3:-}"
  local body_file

  if [[ -z "$kind" || -z "$title" ]]; then
    echo "error: KIND and TITLE are required" >&2
    exit 2
  fi

  if [[ -n "$source" ]]; then
    body_file="$(read_body_file "$source")"
  else
    body_file="$(mktemp)"
    printf '{}\n' > "$body_file"
  fi

  python3 - "$kind" "$title" "$body_file" <<'PY'
import json
import sys
from pathlib import Path

kind = sys.argv[1]
title = sys.argv[2]
extra = json.loads(Path(sys.argv[3]).read_text())

if not isinstance(extra, dict):
    print("error: interaction extra payload must be a JSON object", file=sys.stderr)
    raise SystemExit(2)

payload = {"kind": kind, "title": title}
payload.update(extra)

json.dump(payload, sys.stdout, indent=2)
sys.stdout.write("\n")
PY

  rm -f "$body_file"
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
  adapter-env-template)
    print_adapter_env_template "${2:-}" "${3:-}"
    ;;
  comment-template)
    print_comment_template "${2:-}" "${3:-}"
    ;;
  update-template)
    print_update_template "${2:-}" "${3:-}" "${4:-}"
    ;;
  blocked-template)
    print_blocked_template "${2:-}" "${3:-}" "${4:-}"
    ;;
  interaction-template)
    print_interaction_template "${2:-}" "${3:-}" "${4:-}"
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
  issue-comment-current-template)
    require_auth
    body="${2:-}"
    resume_flag="${3:-}"
    if [[ -z "$body" ]]; then
      echo "error: BODY is required" >&2
      exit 2
    fi
    issue_id="$(resolve_current_issue_id)"
    body_file="$(mktemp)"
    print_comment_template "$body" "$resume_flag" > "$body_file"
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
  issue-interaction-current-template)
    require_auth
    kind="${2:-}"
    title="${3:-}"
    source="${4:-}"
    if [[ -z "$kind" || -z "$title" ]]; then
      echo "error: KIND and TITLE are required" >&2
      exit 2
    fi
    issue_id="$(resolve_current_issue_id)"
    body_file="$(mktemp)"
    print_interaction_template "$kind" "$title" "$source" > "$body_file"
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
  issue-update-current-template)
    require_auth
    status="${2:-}"
    comment="${3:-}"
    resume_flag="${4:-}"
    if [[ -z "$status" || -z "$comment" ]]; then
      echo "error: STATUS and COMMENT are required" >&2
      exit 2
    fi
    issue_id="$(resolve_current_issue_id)"
    body_file="$(mktemp)"
    print_update_template "$status" "$comment" "$resume_flag" > "$body_file"
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
  issue-blocked-current-template)
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
