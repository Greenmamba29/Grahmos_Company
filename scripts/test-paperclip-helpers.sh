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
echo "[1/16] bash syntax checks"
bash -n "$API_SCRIPT"
bash -n "$RUNTIME_CHECK_SCRIPT"

echo
echo "[2/16] help surface includes current-issue helpers"
"$API_SCRIPT" --help | rg 'build-resume-comment|build-done-update|build-markdown-document|build-plan-confirmation|issue-comment-resume-current|issue-done-current|issue-update-current|issue-document-put-current|issue-document-put-markdown-current|issue-document-revisions-current|issue-plan-confirmation-current|issue-interaction-current|issue-interactions-current|issue-interaction-accept-current|issue-interaction-respond-current' >/dev/null

echo
echo "[3/16] sample payload catalog is available"
"$API_SCRIPT" sample-payload help | rg 'comment-resume|plan-document|plan-confirmation|update-done|request-confirmation|interaction-accept|interaction-respond' >/dev/null

echo
echo "[4/16] build-resume-comment emits the expected envelope"
"$API_SCRIPT" build-resume-comment | jq -e '
  .resume == true and
  .body == "Resuming work in this heartbeat."
' >/dev/null

echo
echo "[5/16] build-done-update emits the expected envelope"
"$API_SCRIPT" build-done-update | jq -e '
  .status == "done" and
  .comment == "Completed and verified."
' >/dev/null

echo
echo "[6/16] build-markdown-document emits the expected envelope"
printf '# Plan\n\n- first step\n' > /tmp/paperclip-plan.md
"$API_SCRIPT" build-markdown-document /tmp/paperclip-plan.md "Implementation plan" "Initial draft" | jq -e '
  .title == "Implementation plan" and
  .format == "markdown" and
  (.body | contains("# Plan")) and
  .changeSummary == "Initial draft"
' >/dev/null

echo
echo "[7/16] request_confirmation sample matches expected schema"
"$API_SCRIPT" sample-payload request-confirmation | jq -e '
  .kind == "request_confirmation" and
  .continuationPolicy == "wake_assignee_on_accept" and
  .payload.version == 1 and
  .payload.supersedeOnUserComment == true and
  .payload.target.type == "custom"
' >/dev/null

echo
echo "[8/16] build-plan-confirmation emits the expected envelope"
"$API_SCRIPT" build-plan-confirmation revision-123 ISSUE-123 | jq -e '
  .kind == "request_confirmation" and
  .idempotencyKey == "confirmation:ISSUE-123:plan:revision-123" and
  .payload.target.key == "plan" and
  .payload.target.revisionId == "revision-123"
' >/dev/null

echo
echo "[9/16] plan document sample matches expected schema"
"$API_SCRIPT" sample-payload plan-document | jq -e '
  .title == "Implementation plan" and
  .format == "markdown" and
  (.body | contains("## Summary")) and
  .changeSummary == "Initial plan draft"
' >/dev/null

echo
echo "[10/16] ask_user_questions sample matches expected schema"
"$API_SCRIPT" sample-payload ask-user-questions | jq -e '
  .kind == "ask_user_questions" and
  .continuationPolicy == "wake_assignee" and
  .payload.version == 1 and
  (.payload.questions | length) == 1 and
  .payload.questions[0].selectionMode == "single"
' >/dev/null

echo
echo "[11/16] suggest_tasks sample matches expected schema"
"$API_SCRIPT" sample-payload suggest-tasks | jq -e '
  .kind == "suggest_tasks" and
  .continuationPolicy == "wake_assignee" and
  .payload.version == 1 and
  (.payload.tasks | length) == 2 and
  .payload.tasks[0].clientKey == "task-1"
' >/dev/null

echo
echo "[12/16] interaction accept sample matches expected schema"
"$API_SCRIPT" sample-payload interaction-accept | jq -e '
  (.selectedClientKeys | length) == 1 and
  .selectedClientKeys[0] == "task-1"
' >/dev/null

echo
echo "[13/16] interaction respond sample matches expected schema"
"$API_SCRIPT" sample-payload interaction-respond | jq -e '
  (.answers | length) == 1 and
  .answers[0].questionId == "next-step" and
  .answers[0].optionIds[0] == "option-a"
' >/dev/null

echo
echo "[14/16] plan-confirmation shortcut fails with the expected auth gate"
set +e
"$API_SCRIPT" issue-plan-confirmation-current ISSUE-123 >/tmp/paperclip-plan-confirmation-current.out 2>/tmp/paperclip-plan-confirmation-current.err
plan_confirmation_code=$?
set -e

if [[ "$plan_confirmation_code" -ne 3 ]]; then
  echo "expected issue-plan-confirmation-current to exit 3 without PAPERCLIP_API_KEY, got $plan_confirmation_code" >&2
  exit 1
fi

rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-plan-confirmation-current.err >/dev/null

echo
echo "[15/16] markdown document shortcut fails with the expected auth gate"
set +e
"$API_SCRIPT" issue-document-put-markdown-current plan /tmp/paperclip-plan.md "Implementation plan" "Initial draft" >/tmp/paperclip-document-put-markdown-current.out 2>/tmp/paperclip-document-put-markdown-current.err
document_put_markdown_code=$?
set -e

if [[ "$document_put_markdown_code" -ne 3 ]]; then
  echo "expected issue-document-put-markdown-current to exit 3 without PAPERCLIP_API_KEY, got $document_put_markdown_code" >&2
  exit 1
fi

rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-document-put-markdown-current.err >/dev/null

echo
echo "[16/16] unauthenticated current-issue commands fail with the expected auth gate"
set +e
"$API_SCRIPT" issue-comment-resume-current >/tmp/paperclip-comment-resume-current.out 2>/tmp/paperclip-comment-resume-current.err
comment_resume_code=$?
printf '{"status":"done"}\n' | "$API_SCRIPT" issue-update-current - >/tmp/paperclip-update-current.out 2>/tmp/paperclip-update-current.err
update_code=$?
"$API_SCRIPT" issue-done-current >/tmp/paperclip-done-current.out 2>/tmp/paperclip-done-current.err
done_code=$?
"$API_SCRIPT" sample-payload plan-document | "$API_SCRIPT" issue-document-put-current plan - >/tmp/paperclip-document-put-current.out 2>/tmp/paperclip-document-put-current.err
document_put_code=$?
printf '{"kind":"ask_user_questions"}\n' | "$API_SCRIPT" issue-interaction-current - >/tmp/paperclip-interaction-current.out 2>/tmp/paperclip-interaction-current.err
interaction_code=$?
"$API_SCRIPT" issue-interactions-current >/tmp/paperclip-interactions-current.out 2>/tmp/paperclip-interactions-current.err
interactions_list_code=$?
"$API_SCRIPT" issue-interaction-accept-current 123e4567-e89b-12d3-a456-426614174000 >/tmp/paperclip-interaction-accept-current.out 2>/tmp/paperclip-interaction-accept-current.err
interaction_accept_code=$?
set -e

if [[ "$comment_resume_code" -ne 3 ]]; then
  echo "expected issue-comment-resume-current to exit 3 without PAPERCLIP_API_KEY, got $comment_resume_code" >&2
  exit 1
fi

if [[ "$update_code" -ne 3 ]]; then
  echo "expected issue-update-current to exit 3 without PAPERCLIP_API_KEY, got $update_code" >&2
  exit 1
fi

if [[ "$done_code" -ne 3 ]]; then
  echo "expected issue-done-current to exit 3 without PAPERCLIP_API_KEY, got $done_code" >&2
  exit 1
fi

if [[ "$document_put_code" -ne 3 ]]; then
  echo "expected issue-document-put-current to exit 3 without PAPERCLIP_API_KEY, got $document_put_code" >&2
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

rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-comment-resume-current.err >/dev/null
rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-update-current.err >/dev/null
rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-done-current.err >/dev/null
rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-document-put-current.err >/dev/null
rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-interaction-current.err >/dev/null
rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-interactions-current.err >/dev/null
rg 'PAPERCLIP_API_KEY is required' /tmp/paperclip-interaction-accept-current.err >/dev/null

echo
echo "Smoke test passed."
