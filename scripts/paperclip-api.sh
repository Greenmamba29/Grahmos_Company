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
  ./scripts/paperclip-api.sh issue-resume ISSUE_ID BODY
  ./scripts/paperclip-api.sh issue-resume-current BODY
  ./scripts/paperclip-api.sh issue-reopen ISSUE_ID BODY
  ./scripts/paperclip-api.sh issue-reopen-current BODY
  ./scripts/paperclip-api.sh issue-interrupt ISSUE_ID BODY
  ./scripts/paperclip-api.sh issue-interrupt-current BODY
  ./scripts/paperclip-api.sh issue-interaction ISSUE_ID JSON_FILE|-
  ./scripts/paperclip-api.sh issue-interaction-current JSON_FILE|-
  ./scripts/paperclip-api.sh issue-ask-user-question ISSUE_ID QUESTION_ID PROMPT
  ./scripts/paperclip-api.sh issue-ask-user-question-current QUESTION_ID PROMPT
  ./scripts/paperclip-api.sh issue-suggest-task ISSUE_ID TITLE TASK_TITLE TASK_BODY [BODY]
  ./scripts/paperclip-api.sh issue-suggest-task-current TITLE TASK_TITLE TASK_BODY [BODY]
  ./scripts/paperclip-api.sh issue-confirm-plan ISSUE_ID TITLE BODY REVISION_ID
  ./scripts/paperclip-api.sh issue-confirm-plan-current TITLE BODY REVISION_ID
  ./scripts/paperclip-api.sh issue-update ISSUE_ID JSON_FILE|-
  ./scripts/paperclip-api.sh issue-update-current JSON_FILE|-
  ./scripts/paperclip-api.sh issue-done ISSUE_ID COMMENT
  ./scripts/paperclip-api.sh issue-done-current COMMENT
  ./scripts/paperclip-api.sh issue-in-review ISSUE_ID COMMENT
  ./scripts/paperclip-api.sh issue-in-review-current COMMENT
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
  ./scripts/paperclip-api.sh issue-resume-current "Resuming after the auth fix."
  ./scripts/paperclip-api.sh issue-reopen-current "Reopening this issue for follow-up work."
  ./scripts/paperclip-api.sh issue-interrupt-current "Interrupting current execution pending external input."
  printf '{"body":"Work started.","resume":true}\n' | \
    ./scripts/paperclip-api.sh issue-comment 123e4567-e89b-12d3-a456-426614174000 -
  ./scripts/paperclip-api.sh issue-ask-user-question-current runtime-auth "Which Paperclip secret should back PAPERCLIP_API_KEY?"
  ./scripts/paperclip-api.sh issue-suggest-task-current "Suggested follow-up" "Inject PAPERCLIP_API_KEY" "Add the agent key as a secret-backed env var."
  ./scripts/paperclip-api.sh issue-confirm-plan-current "Approve plan revision" "Please approve the latest plan revision." revision-123
  ./scripts/paperclip-api.sh issue-interaction 123e4567-e89b-12d3-a456-426614174000 interaction.json
  ./scripts/paperclip-api.sh issue-update 123e4567-e89b-12d3-a456-426614174000 payload.json
  ./scripts/paperclip-api.sh issue-update-current payload.json
  ./scripts/paperclip-api.sh issue-done-current "Completed and verified."
  ./scripts/paperclip-api.sh issue-in-review-current "Ready for a named reviewer."
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
  - `issue-resume*`, `issue-reopen*`, `issue-interrupt*`, `issue-done*`, and `issue-in-review*` generate JSON payloads for common issue actions.
  - `issue-ask-user-question*`, `issue-suggest-task*`, and `issue-confirm-plan*` generate JSON payloads for common interaction flows.
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

write_comment_payload() {
  local body="$1"
  local resume="${2:-false}"
  local reopen="${3:-false}"
  local interrupt="${4:-false}"
  local tmp_body
  tmp_body="$(mktemp)"

  python3 - "$body" "$resume" "$reopen" "$interrupt" > "$tmp_body" <<'PY'
import json
import sys

body = sys.argv[1]
resume = sys.argv[2].strip().lower() == "true"
reopen = sys.argv[3].strip().lower() == "true"
interrupt = sys.argv[4].strip().lower() == "true"

payload = {"body": body}
if resume:
    payload["resume"] = True
if reopen:
    payload["reopen"] = True
if interrupt:
    payload["interrupt"] = True

json.dump(payload, sys.stdout)
sys.stdout.write("\n")
PY

  printf '%s\n' "$tmp_body"
}

write_status_payload() {
  local status="$1"
  local comment="$2"
  local tmp_body
  tmp_body="$(mktemp)"

  python3 - "$status" "$comment" > "$tmp_body" <<'PY'
import json
import sys

status = sys.argv[1]
comment = sys.argv[2]

json.dump({"status": status, "comment": comment}, sys.stdout)
sys.stdout.write("\n")
PY

  printf '%s\n' "$tmp_body"
}

write_ask_user_question_payload() {
  local question_id="$1"
  local prompt="$2"
  local tmp_body
  tmp_body="$(mktemp)"

  python3 - "$question_id" "$prompt" > "$tmp_body" <<'PY'
import json
import sys

question_id = sys.argv[1]
prompt = sys.argv[2]

json.dump(
    {
        "kind": "ask_user_questions",
        "questions": [{"id": question_id, "prompt": prompt}],
        "continuationPolicy": "wake_assignee",
    },
    sys.stdout,
)
sys.stdout.write("\n")
PY

  printf '%s\n' "$tmp_body"
}

write_suggest_task_payload() {
  local title="$1"
  local task_title="$2"
  local task_body="$3"
  local body="${4:-Choose the suggested follow-up task.}"
  local tmp_body
  tmp_body="$(mktemp)"

  python3 - "$title" "$task_title" "$task_body" "$body" > "$tmp_body" <<'PY'
import json
import sys

title = sys.argv[1]
task_title = sys.argv[2]
task_body = sys.argv[3]
body = sys.argv[4]

json.dump(
    {
        "kind": "suggest_tasks",
        "title": title,
        "body": body,
        "tasks": [{"title": task_title, "body": task_body}],
        "continuationPolicy": "wake_assignee",
    },
    sys.stdout,
)
sys.stdout.write("\n")
PY

  printf '%s\n' "$tmp_body"
}

write_confirm_plan_payload() {
  local issue_id="$1"
  local title="$2"
  local body="$3"
  local revision_id="$4"
  local tmp_body
  tmp_body="$(mktemp)"

  python3 - "$issue_id" "$title" "$body" "$revision_id" > "$tmp_body" <<'PY'
import json
import sys

issue_id = sys.argv[1]
title = sys.argv[2]
body = sys.argv[3]
revision_id = sys.argv[4]

json.dump(
    {
        "kind": "request_confirmation",
        "title": title,
        "body": body,
        "idempotencyKey": f"confirmation:{issue_id}:plan:{revision_id}",
        "supersedeOnUserComment": True,
        "continuationPolicy": "wake_assignee",
        "documentTarget": {"type": "plan_revision", "revisionId": revision_id},
    },
    sys.stdout,
)
sys.stdout.write("\n")
PY

  printf '%s\n' "$tmp_body"
}

require_value() {
  local value="$1"
  local message="$2"
  if [[ -z "$value" ]]; then
    echo "error: $message" >&2
    exit 2
  fi
}

issue_path() {
  local issue_id="$1"
  local suffix="${2:-}"
  printf '/api/issues/%s%s\n' "$issue_id" "$suffix"
}

request_issue_path() {
  local method="$1"
  local issue_id="$2"
  local suffix="${3:-}"
  local body_file="${4:-}"
  request "$method" "$(issue_path "$issue_id" "$suffix")" "$body_file"
}

request_issue_with_source() {
  local method="$1"
  local issue_id="$2"
  local suffix="$3"
  local source="$4"
  local body_file
  body_file="$(read_body_file "$source")"
  request_issue_path "$method" "$issue_id" "$suffix" "$body_file"
  rm -f "$body_file"
}

request_current_issue_with_source() {
  local method="$1"
  local suffix="$2"
  local source="$3"
  local issue_id
  issue_id="$(resolve_current_issue_id)"
  request_issue_with_source "$method" "$issue_id" "$suffix" "$source"
}

request_issue_with_generated_body() {
  local method="$1"
  local issue_id="$2"
  local suffix="$3"
  local body_file="$4"
  request_issue_path "$method" "$issue_id" "$suffix" "$body_file"
  rm -f "$body_file"
}

request_current_issue_with_generated_body() {
  local method="$1"
  local suffix="$2"
  local body_file="$3"
  local issue_id
  issue_id="$(resolve_current_issue_id)"
  request_issue_with_generated_body "$method" "$issue_id" "$suffix" "$body_file"
}

request_issue_comments() {
  local issue_id="$1"
  local after_comment_id="${2:-}"
  local path
  path="$(issue_path "$issue_id" "/comments")"
  if [[ -n "$after_comment_id" ]]; then
    path="$path?after=$after_comment_id&order=asc"
  fi
  request GET "$path"
}

request_current_issue_comments() {
  local after_comment_id="${1:-}"
  local issue_id
  issue_id="$(resolve_current_issue_id)"
  request_issue_comments "$issue_id" "$after_comment_id"
}

request_issue_generated_comment() {
  local issue_id="$1"
  local body="$2"
  local resume="${3:-false}"
  local reopen="${4:-false}"
  local interrupt="${5:-false}"
  local body_file
  body_file="$(write_comment_payload "$body" "$resume" "$reopen" "$interrupt")"
  request_issue_with_generated_body POST "$issue_id" "/comments" "$body_file"
}

request_current_issue_generated_comment() {
  local body="$1"
  local resume="${2:-false}"
  local reopen="${3:-false}"
  local interrupt="${4:-false}"
  local body_file
  body_file="$(write_comment_payload "$body" "$resume" "$reopen" "$interrupt")"
  request_current_issue_with_generated_body POST "/comments" "$body_file"
}

request_issue_generated_status() {
  local issue_id="$1"
  local status="$2"
  local comment="$3"
  local body_file
  body_file="$(write_status_payload "$status" "$comment")"
  request_issue_with_generated_body PATCH "$issue_id" "" "$body_file"
}

request_current_issue_generated_status() {
  local status="$1"
  local comment="$2"
  local body_file
  body_file="$(write_status_payload "$status" "$comment")"
  request_current_issue_with_generated_body PATCH "" "$body_file"
}

request_issue_generated_interaction() {
  local issue_id="$1"
  local body_file="$2"
  request_issue_with_generated_body POST "$issue_id" "/interactions" "$body_file"
}

request_current_issue_generated_interaction() {
  local body_file="$1"
  request_current_issue_with_generated_body POST "/interactions" "$body_file"
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
    require_value "$issue_id" "ISSUE_ID is required"
    request GET "$(issue_path "$issue_id")"
    ;;
  issue-get-current)
    require_auth
    issue_id="$(resolve_current_issue_id)"
    request GET "$(issue_path "$issue_id")"
    ;;
  issue-comments)
    require_auth
    issue_id="${2:-}"
    after_comment_id="${3:-}"
    require_value "$issue_id" "ISSUE_ID is required"
    request_issue_comments "$issue_id" "$after_comment_id"
    ;;
  issue-comments-current)
    require_auth
    after_comment_id="${2:-}"
    request_current_issue_comments "$after_comment_id"
    ;;
  issue-comment)
    require_auth
    issue_id="${2:-}"
    source="${3:-}"
    require_value "$issue_id" "ISSUE_ID and JSON_FILE|- are required"
    require_value "$source" "ISSUE_ID and JSON_FILE|- are required"
    request_issue_with_source POST "$issue_id" "/comments" "$source"
    ;;
  issue-comment-current)
    require_auth
    source="${2:-}"
    require_value "$source" "JSON_FILE|- is required"
    request_current_issue_with_source POST "/comments" "$source"
    ;;
  issue-resume)
    require_auth
    issue_id="${2:-}"
    body="${3:-}"
    require_value "$issue_id" "ISSUE_ID and BODY are required"
    require_value "$body" "ISSUE_ID and BODY are required"
    request_issue_generated_comment "$issue_id" "$body" true
    ;;
  issue-resume-current)
    require_auth
    body="${2:-}"
    require_value "$body" "BODY is required"
    request_current_issue_generated_comment "$body" true
    ;;
  issue-reopen)
    require_auth
    issue_id="${2:-}"
    body="${3:-}"
    require_value "$issue_id" "ISSUE_ID and BODY are required"
    require_value "$body" "ISSUE_ID and BODY are required"
    request_issue_generated_comment "$issue_id" "$body" true true
    ;;
  issue-reopen-current)
    require_auth
    body="${2:-}"
    require_value "$body" "BODY is required"
    request_current_issue_generated_comment "$body" true true
    ;;
  issue-interrupt)
    require_auth
    issue_id="${2:-}"
    body="${3:-}"
    require_value "$issue_id" "ISSUE_ID and BODY are required"
    require_value "$body" "ISSUE_ID and BODY are required"
    request_issue_generated_comment "$issue_id" "$body" false false true
    ;;
  issue-interrupt-current)
    require_auth
    body="${2:-}"
    require_value "$body" "BODY is required"
    request_current_issue_generated_comment "$body" false false true
    ;;
  issue-interaction)
    require_auth
    issue_id="${2:-}"
    source="${3:-}"
    require_value "$issue_id" "ISSUE_ID and JSON_FILE|- are required"
    require_value "$source" "ISSUE_ID and JSON_FILE|- are required"
    request_issue_with_source POST "$issue_id" "/interactions" "$source"
    ;;
  issue-interaction-current)
    require_auth
    source="${2:-}"
    require_value "$source" "JSON_FILE|- is required"
    request_current_issue_with_source POST "/interactions" "$source"
    ;;
  issue-ask-user-question)
    require_auth
    issue_id="${2:-}"
    question_id="${3:-}"
    prompt="${4:-}"
    require_value "$issue_id" "ISSUE_ID, QUESTION_ID, and PROMPT are required"
    require_value "$question_id" "ISSUE_ID, QUESTION_ID, and PROMPT are required"
    require_value "$prompt" "ISSUE_ID, QUESTION_ID, and PROMPT are required"
    body_file="$(write_ask_user_question_payload "$question_id" "$prompt")"
    request_issue_generated_interaction "$issue_id" "$body_file"
    ;;
  issue-ask-user-question-current)
    require_auth
    question_id="${2:-}"
    prompt="${3:-}"
    require_value "$question_id" "QUESTION_ID and PROMPT are required"
    require_value "$prompt" "QUESTION_ID and PROMPT are required"
    body_file="$(write_ask_user_question_payload "$question_id" "$prompt")"
    request_current_issue_generated_interaction "$body_file"
    ;;
  issue-suggest-task)
    require_auth
    issue_id="${2:-}"
    title="${3:-}"
    task_title="${4:-}"
    task_body="${5:-}"
    body="${6:-Choose the suggested follow-up task.}"
    require_value "$issue_id" "ISSUE_ID, TITLE, TASK_TITLE, and TASK_BODY are required"
    require_value "$title" "ISSUE_ID, TITLE, TASK_TITLE, and TASK_BODY are required"
    require_value "$task_title" "ISSUE_ID, TITLE, TASK_TITLE, and TASK_BODY are required"
    require_value "$task_body" "ISSUE_ID, TITLE, TASK_TITLE, and TASK_BODY are required"
    body_file="$(write_suggest_task_payload "$title" "$task_title" "$task_body" "$body")"
    request_issue_generated_interaction "$issue_id" "$body_file"
    ;;
  issue-suggest-task-current)
    require_auth
    title="${2:-}"
    task_title="${3:-}"
    task_body="${4:-}"
    body="${5:-Choose the suggested follow-up task.}"
    require_value "$title" "TITLE, TASK_TITLE, and TASK_BODY are required"
    require_value "$task_title" "TITLE, TASK_TITLE, and TASK_BODY are required"
    require_value "$task_body" "TITLE, TASK_TITLE, and TASK_BODY are required"
    body_file="$(write_suggest_task_payload "$title" "$task_title" "$task_body" "$body")"
    request_current_issue_generated_interaction "$body_file"
    ;;
  issue-confirm-plan)
    require_auth
    issue_id="${2:-}"
    title="${3:-}"
    body="${4:-}"
    revision_id="${5:-}"
    require_value "$issue_id" "ISSUE_ID, TITLE, BODY, and REVISION_ID are required"
    require_value "$title" "ISSUE_ID, TITLE, BODY, and REVISION_ID are required"
    require_value "$body" "ISSUE_ID, TITLE, BODY, and REVISION_ID are required"
    require_value "$revision_id" "ISSUE_ID, TITLE, BODY, and REVISION_ID are required"
    body_file="$(write_confirm_plan_payload "$issue_id" "$title" "$body" "$revision_id")"
    request_issue_generated_interaction "$issue_id" "$body_file"
    ;;
  issue-confirm-plan-current)
    require_auth
    title="${2:-}"
    body="${3:-}"
    revision_id="${4:-}"
    require_value "$title" "TITLE, BODY, and REVISION_ID are required"
    require_value "$body" "TITLE, BODY, and REVISION_ID are required"
    require_value "$revision_id" "TITLE, BODY, and REVISION_ID are required"
    issue_id="$(resolve_current_issue_id)"
    body_file="$(write_confirm_plan_payload "$issue_id" "$title" "$body" "$revision_id")"
    request_issue_generated_interaction "$issue_id" "$body_file"
    ;;
  issue-update)
    require_auth
    issue_id="${2:-}"
    source="${3:-}"
    require_value "$issue_id" "ISSUE_ID and JSON_FILE|- are required"
    require_value "$source" "ISSUE_ID and JSON_FILE|- are required"
    request_issue_with_source PATCH "$issue_id" "" "$source"
    ;;
  issue-update-current)
    require_auth
    source="${2:-}"
    require_value "$source" "JSON_FILE|- is required"
    request_current_issue_with_source PATCH "" "$source"
    ;;
  issue-done)
    require_auth
    issue_id="${2:-}"
    comment="${3:-}"
    require_value "$issue_id" "ISSUE_ID and COMMENT are required"
    require_value "$comment" "ISSUE_ID and COMMENT are required"
    request_issue_generated_status "$issue_id" "done" "$comment"
    ;;
  issue-done-current)
    require_auth
    comment="${2:-}"
    require_value "$comment" "COMMENT is required"
    request_current_issue_generated_status "done" "$comment"
    ;;
  issue-in-review)
    require_auth
    issue_id="${2:-}"
    comment="${3:-}"
    require_value "$issue_id" "ISSUE_ID and COMMENT are required"
    require_value "$comment" "ISSUE_ID and COMMENT are required"
    request_issue_generated_status "$issue_id" "in_review" "$comment"
    ;;
  issue-in-review-current)
    require_auth
    comment="${2:-}"
    require_value "$comment" "COMMENT is required"
    request_current_issue_generated_status "in_review" "$comment"
    ;;
  issue-blocked)
    require_auth
    issue_id="${2:-}"
    unblock_owner="${3:-}"
    required_action="${4:-}"
    details="${5:-}"
    require_value "$issue_id" "ISSUE_ID, UNBLOCK_OWNER, and REQUIRED_ACTION are required"
    require_value "$unblock_owner" "ISSUE_ID, UNBLOCK_OWNER, and REQUIRED_ACTION are required"
    require_value "$required_action" "ISSUE_ID, UNBLOCK_OWNER, and REQUIRED_ACTION are required"
    body_file="$(write_blocked_payload "$unblock_owner" "$required_action" "$details")"
    request_issue_with_generated_body PATCH "$issue_id" "" "$body_file"
    ;;
  issue-blocked-current)
    require_auth
    unblock_owner="${2:-}"
    required_action="${3:-}"
    details="${4:-}"
    require_value "$unblock_owner" "UNBLOCK_OWNER and REQUIRED_ACTION are required"
    require_value "$required_action" "UNBLOCK_OWNER and REQUIRED_ACTION are required"
    body_file="$(write_blocked_payload "$unblock_owner" "$required_action" "$details")"
    request_current_issue_with_generated_body PATCH "" "$body_file"
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
