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

run_mock_runtime_check() {
  local scenario="$1"
  local port server_pid
  port="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"

  python3 - "$port" "$scenario" <<'PY' &
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1])
scenario = sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        run_issue_match = re.fullmatch(r"/api/heartbeat-runs/[^/]+/issues", self.path)
        if scenario == "degraded-health-auth-blocked":
            if self.path == "/api/health":
                self.send_response(503)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "health unavailable"}).encode())
                return
            if self.path == "/api/auth/get-session":
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Board authentication required"}).encode())
                return
            if run_issue_match:
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Board authentication required"}).encode())
                return

        self.send_response(404)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"error": "not found"}).encode())

    def log_message(self, format, *args):
        return


HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
  server_pid=$!

  trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true' RETURN
  run_expect 2 env \
    PAPERCLIP_API_URL="http://127.0.0.1:$port" \
    PAPERCLIP_AGENT_ID="agent-123" \
    PAPERCLIP_COMPANY_ID="company-123" \
    PAPERCLIP_RUN_ID="run-123" \
    PAPERCLIP_WORKSPACE_CWD="/workspace" \
    PAPERCLIP_WORKSPACE_SOURCE="agent-run" \
    GH_TOKEN="gh-test-token" \
    CLOUD_AGENT_INJECTED_SECRET_NAMES="GH_TOKEN" \
    ./scripts/paperclip-runtime-check.sh
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
  trap - RETURN
}

run_expect 0 ./scripts/paperclip-api.sh help
assert_stdout_contains "issue-interaction-current"
assert_stdout_contains "request-confirmation-template TITLE [JSON_FILE|-]"
assert_stdout_contains "issue-blocked-current-template UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]"
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

run_expect 0 ./scripts/paperclip-operator-unblock.sh paperclip-secret cursor-secret
assert_stdout_contains "Paperclip Cursor Cloud unblock handoff"
assert_stdout_contains "\"status\": \"blocked\""
assert_stdout_contains "\"PAPERCLIP_API_KEY\""
assert_stdout_contains "\"secretId\": \"paperclip-secret\""
assert_stdout_contains "./scripts/paperclip-runtime-check.sh"
pass "paperclip-operator-unblock prints the operator handoff package"
cleanup_last

report_path="$(mktemp)"
run_expect 0 ./scripts/paperclip-write-runtime-report.sh "$report_path" paperclip-secret cursor-secret
assert_stdout_contains "Wrote $report_path"
if ! grep -Fq "# Osiris Hermes Paperclip Runtime Report" "$report_path"; then
  fail "runtime report missing title"
fi
if ! grep -Fq "## Runtime check output" "$report_path"; then
  fail "runtime report missing runtime section"
fi
if ! grep -Fq "## Operator unblock handoff" "$report_path"; then
  fail "runtime report missing unblock section"
fi
rm -f "$report_path"
pass "paperclip-write-runtime-report writes a markdown handoff report"
cleanup_last

run_mock_runtime_check "degraded-health-auth-blocked"
assert_stdout_contains "\"health_status\": 503"
assert_stdout_contains "Health check did not return 200, but auth signals are sufficient to diagnose the blocker."
assert_stdout_contains "Board authentication is not available in this shell session."
assert_stdout_contains "Required action: inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env."
pass "paperclip-runtime-check preserves auth guidance when health is degraded"
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
