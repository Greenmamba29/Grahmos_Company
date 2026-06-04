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
echo "[1/9] bash syntax checks"
bash -n "$API_SCRIPT"
bash -n "$RUNTIME_CHECK_SCRIPT"

echo
echo "[2/9] help surface includes current-issue helpers"
"$API_SCRIPT" --help | rg 'issue-update-current|issue-interaction-current|issue-interactions-current|issue-interaction-accept-current|issue-interaction-respond-current' >/dev/null

echo
echo "[3/9] sample payload catalog is available"
"$API_SCRIPT" sample-payload help | rg 'comment-resume|update-done|request-confirmation|interaction-accept|interaction-respond' >/dev/null

echo
echo "[4/9] request_confirmation sample matches expected schema"
"$API_SCRIPT" sample-payload request-confirmation | jq -e '
  .kind == "request_confirmation" and
  .continuationPolicy == "wake_assignee_on_accept" and
  .payload.version == 1 and
  .payload.supersedeOnUserComment == true and
  .payload.target.type == "custom"
' >/dev/null

echo
echo "[5/9] ask_user_questions sample matches expected schema"
"$API_SCRIPT" sample-payload ask-user-questions | jq -e '
  .kind == "ask_user_questions" and
  .continuationPolicy == "wake_assignee" and
  .payload.version == 1 and
  (.payload.questions | length) == 1 and
  .payload.questions[0].selectionMode == "single"
' >/dev/null

echo
echo "[6/9] suggest_tasks sample matches expected schema"
"$API_SCRIPT" sample-payload suggest-tasks | jq -e '
  .kind == "suggest_tasks" and
  .continuationPolicy == "wake_assignee" and
  .payload.version == 1 and
  (.payload.tasks | length) == 2 and
  .payload.tasks[0].clientKey == "task-1"
' >/dev/null

echo
echo "[7/9] interaction accept sample matches expected schema"
"$API_SCRIPT" sample-payload interaction-accept | jq -e '
  (.selectedClientKeys | length) == 1 and
  .selectedClientKeys[0] == "task-1"
' >/dev/null

echo
echo "[8/9] interaction respond sample matches expected schema"
"$API_SCRIPT" sample-payload interaction-respond | jq -e '
  (.answers | length) == 1 and
  .answers[0].questionId == "next-step" and
  .answers[0].optionIds[0] == "option-a"
' >/dev/null

echo
echo "[9/9] unauthenticated current-issue commands fail with the expected auth gate"
set +e
printf '{"status":"done"}\n' | "$API_SCRIPT" issue-update-current - >/tmp/paperclip-update-current.out 2>/tmp/paperclip-update-current.err
update_code=$?
printf '{"kind":"ask_user_questions"}\n' | "$API_SCRIPT" issue-interaction-current - >/tmp/paperclip-interaction-current.out 2>/tmp/paperclip-interaction-current.err
interaction_code=$?
"$API_SCRIPT" issue-interactions-current >/tmp/paperclip-interactions-current.out 2>/tmp/paperclip-interactions-current.err
interactions_list_code=$?
"$API_SCRIPT" issue-interaction-accept-current 123e4567-e89b-12d3-a456-426614174000 >/tmp/paperclip-interaction-accept-current.out 2>/tmp/paperclip-interaction-accept-current.err
interaction_accept_code=$?
set -e

if [[ "$update_code" -ne 3 ]]; then
  echo "expected issue-update-current to exit 3 without PAPERCLIP_API_KEY, got $update_code" >&2
  exit 1
fi

if [[ "$interaction_code" -ne 3 ]]; then
  echo "expected issue-interaction-current to exit 3 without PAPERCLIP_API_KEY, got $interaction_code" >&2
  exit 1
fi

if [[ "$interactions_list_code" -ne 3 ]]; then
  echo "expected issue-interactions-current to exit 3 without PAPERCLIP_API_KEY, got $interactions_list_code" >&2
  exit 1
fi

if [[ "$interaction_accept_code" -ne 3 ]]; then
  echo "expected issue-interaction-accept-current to exit 3 without PAPERCLIP_API_KEY, got $interaction_accept_code" >&2
  exit 1
fi

rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-update-current.err >/dev/null
rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-interaction-current.err >/dev/null
rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-interactions-current.err >/dev/null
rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-interaction-accept-current.err >/dev/null

echo
echo "Smoke test passed."
