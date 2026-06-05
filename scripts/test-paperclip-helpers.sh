#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

pass_count=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

pass() {
  pass_count=$((pass_count + 1))
  printf 'PASS: %s\n' "$1"
}

run_expect() {
  local expected_exit="$1"
  shift

  local stdout_file stderr_file exit_code
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  if "$@" >"$stdout_file" 2>"$stderr_file"; then
    exit_code=0
  else
    exit_code=$?
  fi

  if [[ "$exit_code" != "$expected_exit" ]]; then
    printf 'STDOUT:\n' >&2
    sed -n '1,120p' "$stdout_file" >&2
    printf 'STDERR:\n' >&2
    sed -n '1,120p' "$stderr_file" >&2
    rm -f "$stdout_file" "$stderr_file"
    fail "expected exit $expected_exit, got $exit_code for command: $*"
  fi

  LAST_STDOUT_FILE="$stdout_file"
  LAST_STDERR_FILE="$stderr_file"
}

assert_stdout_contains() {
  local needle="$1"
  if ! grep -Fq "$needle" "$LAST_STDOUT_FILE"; then
    printf 'STDOUT:\n' >&2
    sed -n '1,160p' "$LAST_STDOUT_FILE" >&2
    fail "stdout missing expected text: $needle"
  fi
}

assert_stderr_contains() {
  local needle="$1"
  if ! grep -Fq "$needle" "$LAST_STDERR_FILE"; then
    printf 'STDERR:\n' >&2
    sed -n '1,160p' "$LAST_STDERR_FILE" >&2
    fail "stderr missing expected text: $needle"
  fi
}

cleanup_last() {
  rm -f "${LAST_STDOUT_FILE:-}" "${LAST_STDERR_FILE:-}"
  unset LAST_STDOUT_FILE LAST_STDERR_FILE
}

run_expect 0 ./scripts/paperclip-api.sh help
assert_stdout_contains "issue-interaction-current"
assert_stdout_contains "interaction-respond ISSUE_ID INTERACTION_ID JSON_FILE|-"
assert_stdout_contains "issue-blocked-current UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]"
pass "paperclip-api help advertises current interaction commands"
cleanup_last

run_expect 2 env -u PAPERCLIP_API_URL ./scripts/paperclip-api.sh health
assert_stderr_contains "error: PAPERCLIP_API_URL is required"
pass "paperclip-api health fails fast without API URL"
cleanup_last

run_expect 3 env -u PAPERCLIP_API_KEY PAPERCLIP_API_URL="https://example.invalid" ./scripts/paperclip-api.sh me
assert_stderr_contains "error: PAPERCLIP_API_KEY is required for this command"
pass "paperclip-api me fails fast without API key"
cleanup_last

run_expect 0 env PAPERCLIP_TASK_ID="issue-123" ./scripts/paperclip-api.sh current-issue-id
assert_stdout_contains "issue-123"
pass "paperclip-api current-issue-id prefers PAPERCLIP_TASK_ID"
cleanup_last

run_expect 0 ./scripts/paperclip-send-current.sh --print-command blocked-current
assert_stdout_contains "./scripts/paperclip-api.sh issue-update-current paperclip/payloads/blocked-current.json"
pass "paperclip-send-current prints blocked-current command"
cleanup_last

run_expect 0 ./scripts/paperclip-send-current.sh --print-command gra-39-echo-blocked
assert_stdout_contains "./scripts/paperclip-api.sh issue-update-current paperclip/payloads/gra-39-echo-model-blocked.json"
pass "paperclip-send-current prints gra-39-echo-blocked command"
cleanup_last

run_expect 2 ./scripts/paperclip-send-current.sh nope
assert_stderr_contains "error: unknown mode: nope"
pass "paperclip-send-current rejects unknown mode"
cleanup_last

run_expect 1 env \
  -u PAPERCLIP_API_URL \
  -u PAPERCLIP_AGENT_ID \
  -u PAPERCLIP_COMPANY_ID \
  -u PAPERCLIP_RUN_ID \
  -u PAPERCLIP_WORKSPACE_CWD \
  -u PAPERCLIP_WORKSPACE_SOURCE \
  ./scripts/paperclip-runtime-check.sh
assert_stderr_contains "Missing required environment variables:"
pass "paperclip-runtime-check reports missing runtime env"
cleanup_last

printf 'All %d Paperclip helper smoke tests passed.\n' "$pass_count"
