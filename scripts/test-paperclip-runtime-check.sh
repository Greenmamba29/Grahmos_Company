#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_SCRIPT="$ROOT_DIR/scripts/paperclip-runtime-check.sh"

TMP_DIR="$(mktemp -d)"
STATE_FILE="$TMP_DIR/state.json"
PORT_FILE="$TMP_DIR/port"
SERVER_LOG="$TMP_DIR/server.log"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [[ "$expected" != "$actual" ]]; then
    printf 'assertion failed: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'assertion failed: %s\nmissing substring: %s\nin: %s\n' "$message" "$needle" "$haystack" >&2
    exit 1
  fi
}

write_state() {
  local mode="$1"
  cat > "$STATE_FILE" <<EOF
{
  "mode": "$mode"
}
EOF
}

start_server() {
  STATE_FILE="$STATE_FILE" PORT_FILE="$PORT_FILE" python3 - <<'PY' >"$SERVER_LOG" 2>&1 &
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

state_path = Path(os.environ["STATE_FILE"])
port_file = Path(os.environ["PORT_FILE"])


def load_state():
    return json.loads(state_path.read_text())


def send_json(handler, status, payload):
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        mode = load_state()["mode"]
        auth = self.headers.get("Authorization")

        if self.path == "/api/health":
            send_json(
                self,
                200,
                {
                    "status": "ok",
                    "deploymentMode": "authenticated",
                    "deploymentExposure": "private",
                },
            )
            return

        if self.path == "/api/auth/get-session":
            if mode == "board-session":
                send_json(self, 200, {"user": {"id": "board-user"}})
            else:
                send_json(self, 401, {"error": "Board authentication required"})
            return

        if self.path == "/api/heartbeat-runs/run-123/issues":
            if mode == "board-session":
                send_json(self, 200, [{"id": "run-issue-id", "title": "Run issue"}])
            else:
                send_json(self, 401, {"error": "Unauthorized"})
            return

        if self.path == "/api/agents/me":
            if mode in {"bearer-success", "bearer-bad"} and auth == "Bearer test-key":
                if mode == "bearer-success":
                    send_json(self, 200, {"id": "agent-1"})
                else:
                    send_json(self, 401, {"error": "Unauthorized"})
                return
            send_json(self, 401, {"error": "Unauthorized"})
            return

        if self.path == "/api/agents/me/inbox-lite":
            if mode == "bearer-success" and auth == "Bearer test-key":
                send_json(self, 200, [{"id": "inbox-issue-id", "title": "Inbox issue"}])
                return
            send_json(self, 401, {"error": "Unauthorized"})
            return

        send_json(self, 404, {"error": "Not found"})

    def log_message(self, *_args):
        return


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
port_file.write_text(str(server.server_address[1]), encoding="utf-8")
server.serve_forever()
PY
  SERVER_PID="$!"

  for _ in $(seq 1 50); do
    if [[ -s "$PORT_FILE" ]]; then
      return 0
    fi
    sleep 0.1
  done

  echo "mock Paperclip server failed to start" >&2
  exit 1
}

run_check() {
  local output_file="$1"
  shift
  set +e
  (
    export PAPERCLIP_API_URL="$BASE_URL"
    export PAPERCLIP_AGENT_ID="agent-123"
    export PAPERCLIP_COMPANY_ID="company-123"
    export PAPERCLIP_RUN_ID="run-123"
    export PAPERCLIP_WORKSPACE_CWD="/workspace"
    export PAPERCLIP_WORKSPACE_SOURCE="github"
    "$@"
  ) >"$output_file" 2>&1
  local exit_code=$?
  set -e
  printf '%s\n' "$exit_code"
}

write_state "board-session"
start_server
BASE_URL="http://127.0.0.1:$(<"$PORT_FILE")"

missing_env_output="$TMP_DIR/missing-env.out"
missing_env_code="$(run_check "$missing_env_output" env -u PAPERCLIP_API_URL "$CHECK_SCRIPT")"
assert_eq "1" "$missing_env_code" "missing env should exit 1"
assert_contains "$(<"$missing_env_output")" "Missing required environment variables: PAPERCLIP_API_URL" "missing env output should name the missing variable"

board_output="$TMP_DIR/board.out"
write_state "board-session"
board_code="$(run_check "$board_output" "$CHECK_SCRIPT")"
assert_eq "0" "$board_code" "board-authenticated session should exit 0"
assert_contains "$(<"$board_output")" "\"run_issues_accessible\": true" "board session output should show run issues access"
assert_contains "$(<"$board_output")" "Current run issue lookup succeeded via board session" "board session output should describe the success path"

blocked_output="$TMP_DIR/blocked.out"
write_state "blocked-no-auth"
blocked_code="$(run_check "$blocked_output" "$CHECK_SCRIPT")"
assert_eq "2" "$blocked_code" "missing board session and bearer auth should exit 2"
assert_contains "$(<"$blocked_output")" "\"api_key_present\": false" "blocked output should note the missing API key"
assert_contains "$(<"$blocked_output")" "Board authentication is not available in this shell session." "blocked output should describe the board-session failure"

bearer_success_output="$TMP_DIR/bearer-success.out"
write_state "bearer-success"
bearer_success_code="$(run_check "$bearer_success_output" env PAPERCLIP_API_KEY="test-key" "$CHECK_SCRIPT")"
assert_eq "0" "$bearer_success_code" "valid bearer auth should exit 0"
assert_contains "$(<"$bearer_success_output")" "\"bearer_me_status\": 200" "bearer success output should show authenticated agent access"
assert_contains "$(<"$bearer_success_output")" "Current issue lookup succeeded via PAPERCLIP_API_KEY" "bearer success output should describe the bearer-token path"

bearer_bad_output="$TMP_DIR/bearer-bad.out"
write_state "bearer-bad"
bearer_bad_code="$(run_check "$bearer_bad_output" env PAPERCLIP_API_KEY="test-key" "$CHECK_SCRIPT")"
assert_eq "3" "$bearer_bad_code" "rejected bearer auth should exit 3"
assert_contains "$(<"$bearer_bad_output")" "A bearer token is present, but Paperclip rejected agent authentication." "bearer rejection output should describe the auth failure"
assert_contains "$(<"$bearer_bad_output")" "{\"error\": \"Unauthorized\"}" "bearer rejection output should include the server response"

echo "paperclip-runtime-check smoke tests passed"
