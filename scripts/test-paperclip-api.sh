#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_SCRIPT="$ROOT_DIR/scripts/paperclip-api.sh"

TMP_DIR="$(mktemp -d)"
STATE_FILE="$TMP_DIR/state.json"
REQUESTS_LOG="$TMP_DIR/requests.jsonl"
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

request_count() {
  python3 - "$REQUESTS_LOG" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
if not path.exists():
    print(0)
else:
    print(sum(1 for _ in path.open()))
PY
}

clear_requests() {
  : > "$REQUESTS_LOG"
}

last_request_field() {
  local expression="$1"
  python3 - "$REQUESTS_LOG" "$expression" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expression = sys.argv[2]
lines = [line for line in path.read_text().splitlines() if line.strip()]
record = json.loads(lines[-1])
value = eval(expression, {"__builtins__": {}}, {"record": record})
if isinstance(value, (dict, list)):
    print(json.dumps(value))
else:
    print(value)
PY
}

write_state() {
  local run_issue_mode="$1"
  cat > "$STATE_FILE" <<EOF
{
  "run_issue_mode": "$run_issue_mode",
  "run_items": [
    {
      "id": "run-issue-id",
      "identifier": "GRA-101",
      "title": "Run issue"
    }
  ],
  "inbox_items": [
    {
      "id": "inbox-issue-id",
      "identifier": "GRA-202",
      "title": "Inbox issue"
    }
  ]
}
EOF
}

start_server() {
  STATE_FILE="$STATE_FILE" REQUESTS_LOG="$REQUESTS_LOG" PORT_FILE="$PORT_FILE" python3 - <<'PY' >"$SERVER_LOG" 2>&1 &
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

state_path = Path(os.environ["STATE_FILE"])
requests_log = Path(os.environ["REQUESTS_LOG"])
port_file = Path(os.environ["PORT_FILE"])


def load_state():
    return json.loads(state_path.read_text())


def record(handler, body):
    entry = {
        "method": handler.command,
        "path": handler.path,
        "headers": {key.lower(): value for key, value in handler.headers.items()},
        "body": body.decode("utf-8", "replace"),
    }
    with requests_log.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry) + "\n")


def send_json(handler, status, payload):
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def authorized(handler):
    return handler.headers.get("Authorization") == "Bearer test-key"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        body = b""
        record(self, body)
        state = load_state()

        if parsed.path == "/api/health":
            send_json(self, 200, {"status": "ok"})
            return

        if parsed.path == "/api/auth/get-session":
            send_json(self, 401, {"error": "Board authentication required"})
            return

        if parsed.path == "/api/heartbeat-runs/run-123/issues":
            if state["run_issue_mode"] == "success":
                send_json(self, 200, state["run_items"])
            else:
                send_json(self, 401, {"error": "Unauthorized"})
            return

        if parsed.path == "/api/agents/me/inbox-lite":
            if not authorized(self):
                send_json(self, 401, {"error": "Unauthorized"})
                return
            send_json(self, 200, state["inbox_items"])
            return

        if parsed.path == "/api/issues/run-issue-id" or parsed.path == "/api/issues/inbox-issue-id":
            if not authorized(self):
                send_json(self, 401, {"error": "Unauthorized"})
                return
            send_json(self, 200, {"id": parsed.path.rsplit("/", 1)[-1], "title": "Issue details"})
            return

        if parsed.path.endswith("/comments"):
            if not authorized(self):
                send_json(self, 401, {"error": "Unauthorized"})
                return
            send_json(
                self,
                200,
                {
                    "items": [{"id": "comment-1", "body": "Existing comment"}],
                    "query": parse_qs(parsed.query),
                },
            )
            return

        send_json(self, 404, {"error": "Not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        record(self, body)

        if not authorized(self):
            send_json(self, 401, {"error": "Unauthorized"})
            return

        if parsed.path.endswith("/comments") or parsed.path.endswith("/interactions"):
            send_json(self, 200, {"ok": True, "path": parsed.path})
            return

        send_json(self, 404, {"error": "Not found"})

    def do_PATCH(self):
        parsed = urlparse(self.path)
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        record(self, body)

        if not authorized(self):
            send_json(self, 401, {"error": "Unauthorized"})
            return

        if parsed.path == "/api/issues/run-issue-id" or parsed.path == "/api/issues/inbox-issue-id":
            send_json(self, 200, {"ok": True, "path": parsed.path})
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

run_api() {
  PAPERCLIP_API_URL="$BASE_URL" PAPERCLIP_RUN_ID="run-123" "$API_SCRIPT" "$@"
}

run_api_with_key() {
  PAPERCLIP_API_URL="$BASE_URL" PAPERCLIP_RUN_ID="run-123" PAPERCLIP_API_KEY="test-key" "$API_SCRIPT" "$@"
}

write_state "success"
clear_requests
start_server
BASE_URL="http://127.0.0.1:$(<"$PORT_FILE")"

clear_requests
task_id_output="$(PAPERCLIP_API_URL="$BASE_URL" PAPERCLIP_TASK_ID="task-from-env" "$API_SCRIPT" current-issue-id)"
assert_eq "task-from-env" "$task_id_output" "PAPERCLIP_TASK_ID should override network lookups"
assert_eq "0" "$(request_count)" "PAPERCLIP_TASK_ID resolution should not hit the API"

write_state "success"
clear_requests
run_issue_output="$(run_api current-issue-id)"
assert_eq "run-issue-id" "$run_issue_output" "current-issue-id should prefer run-bound issues"
assert_eq "/api/heartbeat-runs/run-123/issues" "$(last_request_field 'record["path"]')" "run-bound lookup should hit the heartbeat issues endpoint"

write_state "unauthorized"
clear_requests
inbox_issue_output="$(run_api_with_key current-issue-id)"
assert_eq "inbox-issue-id" "$inbox_issue_output" "current-issue-id should fall back to inbox-lite with bearer auth"
assert_eq "2" "$(request_count)" "fallback resolution should probe run issues then inbox-lite"
assert_eq "/api/agents/me/inbox-lite" "$(last_request_field 'record["path"]')" "fallback resolution should end at inbox-lite"

write_state "success"
clear_requests
current_run_issues="$(run_api current-run-issues)"
assert_contains "$current_run_issues" "run-issue-id" "current-run-issues should return the run-bound issue list"

write_state "success"
clear_requests
comment_response="$(printf '{"body":"Work started.","resume":true}\n' | run_api_with_key issue-comment-current -)"
assert_contains "$comment_response" "\"ok\": true" "issue-comment-current should succeed against the mock API"
assert_eq "POST" "$(last_request_field 'record["method"]')" "issue-comment-current should use POST"
assert_eq "/api/issues/run-issue-id/comments" "$(last_request_field 'record["path"]')" "issue-comment-current should target the resolved issue path"
assert_eq "Bearer test-key" "$(last_request_field 'record["headers"]["authorization"]')" "issue-comment-current should send bearer auth"
assert_eq "run-123" "$(last_request_field 'record["headers"]["x-paperclip-run-id"]')" "issue-comment-current should send the run id"
assert_contains "$(last_request_field 'record["body"]')" "\"resume\":true" "issue-comment-current should forward the raw JSON body"

write_state "success"
clear_requests
interaction_response="$(printf '{"kind":"ask_user_questions","questions":[{"id":"q1","prompt":"Need input"}]}\n' | run_api_with_key issue-interaction-current -)"
assert_contains "$interaction_response" "\"ok\": true" "issue-interaction-current should succeed against the mock API"
assert_eq "/api/issues/run-issue-id/interactions" "$(last_request_field 'record["path"]')" "issue-interaction-current should target the interactions endpoint"
assert_contains "$(last_request_field 'record["body"]')" "\"kind\":\"ask_user_questions\"" "issue-interaction-current should forward the raw JSON body"

write_state "success"
clear_requests
get_response="$(run_api_with_key issue-get-current)"
assert_contains "$get_response" "\"id\": \"run-issue-id\"" "issue-get-current should fetch the resolved issue"
assert_eq "/api/issues/run-issue-id" "$(last_request_field 'record["path"]')" "issue-get-current should target the resolved issue path"

write_state "success"
clear_requests
comments_response="$(run_api_with_key issue-comments-current comment-99)"
assert_contains "$comments_response" "\"comment-1\"" "issue-comments-current should fetch comments"
assert_eq "/api/issues/run-issue-id/comments?after=comment-99&order=asc" "$(last_request_field 'record["path"]')" "issue-comments-current should forward pagination parameters"

write_state "success"
clear_requests
update_response="$(printf '{"status":"done","comment":"Finished work."}\n' | run_api_with_key issue-update-current -)"
assert_contains "$update_response" "\"ok\": true" "issue-update-current should succeed against the mock API"
assert_eq "PATCH" "$(last_request_field 'record["method"]')" "issue-update-current should use PATCH"
assert_eq "/api/issues/run-issue-id" "$(last_request_field 'record["path"]')" "issue-update-current should target the resolved issue path"
assert_contains "$(last_request_field 'record["body"]')" "\"status\":\"done\"" "issue-update-current should forward the raw JSON body"

write_state "success"
clear_requests
blocked_response="$(run_api_with_key issue-blocked-current "Paperclip operator" "Inject PAPERCLIP_API_KEY" "Current shell has no control-plane auth")"
assert_contains "$blocked_response" "\"ok\": true" "issue-blocked-current should succeed against the mock API"
assert_eq "/api/issues/run-issue-id" "$(last_request_field 'record["path"]')" "issue-blocked-current should patch the resolved issue"
assert_contains "$(last_request_field 'record["body"]')" "\"status\": \"blocked\"" "issue-blocked-current should set blocked status"
assert_contains "$(last_request_field 'record["body"]')" "Unblock owner: Paperclip operator" "issue-blocked-current should include the unblock owner in the generated comment"

echo "paperclip-api smoke tests passed"
