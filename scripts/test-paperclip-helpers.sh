#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_SCRIPT="$ROOT_DIR/scripts/paperclip-api.sh"
RUNTIME_CHECK_SCRIPT="$ROOT_DIR/scripts/paperclip-runtime-check.sh"

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "missing required command: $name" >&2
    exit 1
  fi
}

require_command bash
require_command jq

echo "Paperclip helper smoke test"
echo "==========================="

echo
echo "[1/7] bash syntax checks"
bash -n "$API_SCRIPT"
bash -n "$RUNTIME_CHECK_SCRIPT"

echo
echo "[2/7] help surface includes current-issue helpers"
"$API_SCRIPT" --help | rg 'issue-update-current|issue-interaction-current' >/dev/null

echo
echo "[3/7] sample payload catalog is available"
"$API_SCRIPT" sample-payload help | rg 'comment-resume|update-done|request-confirmation' >/dev/null

echo
echo "[4/7] request_confirmation sample matches expected schema"
"$API_SCRIPT" sample-payload request-confirmation | jq -e '
  .kind == "request_confirmation" and
  .continuationPolicy == "wake_assignee_on_accept" and
  .payload.version == 1 and
  .payload.supersedeOnUserComment == true and
  .payload.target.type == "custom"
' >/dev/null

echo
echo "[5/7] ask_user_questions sample matches expected schema"
"$API_SCRIPT" sample-payload ask-user-questions | jq -e '
  .kind == "ask_user_questions" and
  .continuationPolicy == "wake_assignee" and
  .payload.version == 1 and
  (.payload.questions | length) == 1 and
  .payload.questions[0].selectionMode == "single"
' >/dev/null

echo
echo "[6/7] suggest_tasks sample matches expected schema"
"$API_SCRIPT" sample-payload suggest-tasks | jq -e '
  .kind == "suggest_tasks" and
  .continuationPolicy == "wake_assignee" and
  .payload.version == 1 and
  (.payload.tasks | length) == 2 and
  .payload.tasks[0].clientKey == "task-1"
' >/dev/null

echo
echo "[7/7] unauthenticated current-issue commands fail with the expected auth gate"
set +e
printf '{"status":"done"}\n' | "$API_SCRIPT" issue-update-current - >/tmp/paperclip-update-current.out 2>/tmp/paperclip-update-current.err
update_code=$?
printf '{"kind":"ask_user_questions"}\n' | "$API_SCRIPT" issue-interaction-current - >/tmp/paperclip-interaction-current.out 2>/tmp/paperclip-interaction-current.err
interaction_code=$?
set -e

if [[ "$update_code" -ne 3 ]]; then
  echo "expected issue-update-current to exit 3 without PAPERCLIP_API_KEY, got $update_code" >&2
  exit 1
fi

if [[ "$interaction_code" -ne 3 ]]; then
  echo "expected issue-interaction-current to exit 3 without PAPERCLIP_API_KEY, got $interaction_code" >&2
  exit 1
fi

rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-update-current.err >/dev/null
rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-interaction-current.err >/dev/null

echo
echo "Smoke test passed."
