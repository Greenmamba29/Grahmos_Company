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
assert_stdout_contains "request-confirmation-template TITLE [JSON_FILE|-]"
assert_stdout_contains "issue-blocked-current-template UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]"
assert_stdout_contains "agent-inject-paperclip-key-current PAPERCLIP_SECRET_ID [VERSION]"
assert_stdout_contains "agent-inject-paperclip-key-current-by-query SECRET_QUERY [VERSION]"
assert_stdout_contains "secret-id-from-json JSON_FILE|- QUERY"
pass "paperclip-api help advertises template and current-issue commands"
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

run_expect 0 env PAPERCLIP_AGENT_ID="agent-123" ./scripts/paperclip-api.sh current-agent-id
assert_stdout_contains "agent-123"
pass "paperclip-api current-agent-id prefers PAPERCLIP_AGENT_ID"
cleanup_last

run_expect 0 env PAPERCLIP_COMPANY_ID="company-123" ./scripts/paperclip-api.sh current-company-id
assert_stdout_contains "company-123"
pass "paperclip-api current-company-id prefers PAPERCLIP_COMPANY_ID"
cleanup_last

run_expect 0 ./scripts/paperclip-api.sh adapter-env-template paperclip-secret cursor-secret
assert_stdout_contains "\"PAPERCLIP_API_KEY\""
assert_stdout_contains "\"secretId\": \"paperclip-secret\""
assert_stdout_contains "\"CURSOR_API_KEY\""
assert_stdout_contains "\"secretId\": \"cursor-secret\""
pass "adapter-env-template prints cursor cloud secret refs"
cleanup_last

run_expect 0 ./scripts/paperclip-api.sh current-issue-playbook
assert_stdout_contains "issue-get-current"
assert_stdout_contains "issue-update-current-template done"
assert_stdout_contains "issue-blocked-current-template"
pass "current-issue-playbook prints execution-contract workflow"
cleanup_last

run_expect 0 ./scripts/paperclip-api.sh comment-template "Resume now" true
assert_stdout_contains "\"body\": \"Resume now\""
assert_stdout_contains "\"resume\": true"
pass "comment-template emits structured resume payload"
cleanup_last

run_expect 0 ./scripts/paperclip-api.sh blocked-template "Paperclip operator" "Inject key" "Missing auth"
assert_stdout_contains "\"status\": \"blocked\""
assert_stdout_contains "Unblock owner: Paperclip operator"
assert_stdout_contains "Required action: Inject key"
pass "blocked-template emits blocked disposition payload"
cleanup_last

run_expect 0 ./scripts/paperclip-api.sh ask-user-questions-template "Need input"
assert_stdout_contains "\"kind\": \"ask_user_questions\""
assert_stdout_contains "\"title\": \"Need input\""
pass "ask-user-questions-template emits interaction payload"
cleanup_last

agent_json_file="$(mktemp)"
cat >"$agent_json_file" <<'EOF'
{
  "id": "agent-123",
  "adapterType": "cursor_cloud",
  "adapterConfig": {
    "repoUrl": "https://github.com/example/repo",
    "env": {
      "CURSOR_API_KEY": {
        "type": "secret_ref",
        "secretId": "cursor-secret",
        "version": "latest"
      }
    }
  }
}
EOF

run_expect 0 ./scripts/paperclip-api.sh agent-env-patch-template "$agent_json_file" PAPERCLIP_API_KEY paperclip-secret
assert_stdout_contains "\"replaceAdapterConfig\": true"
assert_stdout_contains "\"PAPERCLIP_API_KEY\""
assert_stdout_contains "\"secretId\": \"paperclip-secret\""
assert_stdout_contains "\"CURSOR_API_KEY\""
pass "agent-env-patch-template merges a secret ref into adapterConfig.env"
cleanup_last

run_expect 0 ./scripts/paperclip-api.sh agent-paperclip-key-patch-template "$agent_json_file" paperclip-secret 7
assert_stdout_contains "\"PAPERCLIP_API_KEY\""
assert_stdout_contains "\"version\": 7"
pass "agent-paperclip-key-patch-template supports explicit secret versions"
cleanup_last

secrets_json_file="$(mktemp)"
cat >"$secrets_json_file" <<'EOF'
[
  {
    "id": "secret-111",
    "name": "Osiris Paperclip Agent Key",
    "key": "osiris-paperclip-agent-key"
  },
  {
    "id": "secret-222",
    "name": "Cursor API Key",
    "key": "cursor-api-key"
  }
]
EOF

run_expect 0 ./scripts/paperclip-api.sh secret-id-from-json "$secrets_json_file" "osiris-paperclip-agent-key"
assert_stdout_contains "secret-111"
pass "secret-id-from-json prefers exact key/name matches"
cleanup_last

rm -f "$secrets_json_file"

rm -f "$agent_json_file"

run_expect 0 ./scripts/paperclip-operator-unblock.sh paperclip-secret cursor-secret
assert_stdout_contains "Paperclip Cursor Cloud unblock handoff"
assert_stdout_contains "\"status\": \"blocked\""
assert_stdout_contains "\"PAPERCLIP_API_KEY\""
assert_stdout_contains "\"secretId\": \"paperclip-secret\""
assert_stdout_contains "./scripts/paperclip-runtime-check.sh"
pass "paperclip-operator-unblock prints the operator handoff package"
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
