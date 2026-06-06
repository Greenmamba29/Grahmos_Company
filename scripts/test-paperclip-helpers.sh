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

assert_stdout_json_value() {
  local path="$1"
  local expected="$2"
  python3 - "$LAST_STDOUT_FILE" "$path" "$expected" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
path = sys.argv[2].split(".")
expected = sys.argv[3]
cur = data
for part in path:
    cur = cur[part]
actual = "true" if cur is True else "false" if cur is False else "null" if cur is None else str(cur)
if actual != expected:
    raise SystemExit(f"expected {sys.argv[2]}={expected!r}, got {actual!r}")
PY
}

assert_stdout_json_nonempty() {
  local path="$1"
  python3 - "$LAST_STDOUT_FILE" "$path" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
cur = data
for part in sys.argv[2].split("."):
    cur = cur[part]
if not isinstance(cur, str) or not cur:
    raise SystemExit(f"expected non-empty string at {sys.argv[2]}")
PY
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
        run_log_match = re.fullmatch(r"/api/heartbeat-runs/[^/]+/log\?offset=0&limitBytes=4096", self.path)
        workspace_ops_match = re.fullmatch(r"/api/heartbeat-runs/[^/]+/workspace-operations", self.path)
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
            if run_log_match or workspace_ops_match:
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Board authentication required"}).encode())
                return
        if scenario == "board-session-ok":
            if self.path == "/api/health":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {
                            "status": "ok",
                            "deploymentMode": "authenticated",
                            "deploymentExposure": "private",
                        }
                    ).encode()
                )
                return
            if self.path == "/api/auth/get-session":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"user": {"id": "user-123"}}).encode())
                return
            if run_issue_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps([{"id": "issue-1"}]).encode())
                return
            if run_log_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"lines": []}).encode())
                return
            if workspace_ops_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"items": []}).encode())
                return
        if scenario == "api-key-ok":
            auth = self.headers.get("Authorization", "")
            if self.path == "/api/health":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {
                            "status": "ok",
                            "deploymentMode": "authenticated",
                            "deploymentExposure": "private",
                        }
                    ).encode()
                )
                return
            if self.path == "/api/auth/get-session":
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Board authentication required"}).encode())
                return
            if run_issue_match or run_log_match or workspace_ops_match:
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Unauthorized"}).encode())
                return
            if self.path == "/api/agents/me" and auth.startswith("Bearer "):
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"id": "agent-123"}).encode())
                return
            if self.path == "/api/agents/me/inbox-lite" and auth.startswith("Bearer "):
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"items": [{"id": "issue-1"}]}).encode())
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

run_mock_runtime_check_json() {
  local scenario="$1"
  local expected_exit="${2:-2}"
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
        run_log_match = re.fullmatch(r"/api/heartbeat-runs/[^/]+/log\?offset=0&limitBytes=4096", self.path)
        workspace_ops_match = re.fullmatch(r"/api/heartbeat-runs/[^/]+/workspace-operations", self.path)
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
            if run_log_match or workspace_ops_match:
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Board authentication required"}).encode())
                return
        if scenario == "board-session-ok":
            if self.path == "/api/health":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {
                            "status": "ok",
                            "deploymentMode": "authenticated",
                            "deploymentExposure": "private",
                        }
                    ).encode()
                )
                return
            if self.path == "/api/auth/get-session":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"user": {"id": "user-123"}}).encode())
                return
            if run_issue_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps([{"id": "issue-1"}]).encode())
                return
            if run_log_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"lines": []}).encode())
                return
            if workspace_ops_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"items": []}).encode())
                return
        if scenario == "api-key-ok":
            auth = self.headers.get("Authorization", "")
            if self.path == "/api/health":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {
                            "status": "ok",
                            "deploymentMode": "authenticated",
                            "deploymentExposure": "private",
                        }
                    ).encode()
                )
                return
            if self.path == "/api/auth/get-session":
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Board authentication required"}).encode())
                return
            if run_issue_match or run_log_match or workspace_ops_match:
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Unauthorized"}).encode())
                return
            if self.path == "/api/agents/me" and auth.startswith("Bearer "):
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"id": "agent-123"}).encode())
                return
            if self.path == "/api/agents/me/inbox-lite" and auth.startswith("Bearer "):
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"items": [{"id": "issue-1"}]}).encode())
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
  run_expect "$expected_exit" env \
    PAPERCLIP_API_URL="http://127.0.0.1:$port" \
    PAPERCLIP_AGENT_ID="agent-123" \
    PAPERCLIP_COMPANY_ID="company-123" \
    PAPERCLIP_RUN_ID="run-123" \
    PAPERCLIP_WORKSPACE_CWD="/workspace" \
    PAPERCLIP_WORKSPACE_SOURCE="agent-run" \
    PAPERCLIP_API_KEY="${PAPERCLIP_API_KEY:-}" \
    GH_TOKEN="gh-test-token" \
    CLOUD_AGENT_INJECTED_SECRET_NAMES="GH_TOKEN" \
    ./scripts/paperclip-runtime-check.sh --json
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
  trap - RETURN
}

run_mock_heartbeat_next_action() {
  local scenario="$1"
  local port server_pid output_dir
  port="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"
  output_dir="$(mktemp -d)"

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
        run_log_match = re.fullmatch(r"/api/heartbeat-runs/[^/]+/log\?offset=0&limitBytes=4096", self.path)
        workspace_ops_match = re.fullmatch(r"/api/heartbeat-runs/[^/]+/workspace-operations", self.path)
        auth = self.headers.get("Authorization", "")
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
            if run_issue_match or run_log_match or workspace_ops_match:
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Board authentication required"}).encode())
                return
        if scenario == "board-session-ok":
            if self.path == "/api/health":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {
                            "status": "ok",
                            "deploymentMode": "authenticated",
                            "deploymentExposure": "private",
                        }
                    ).encode()
                )
                return
            if self.path == "/api/auth/get-session":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"user": {"id": "user-123"}}).encode())
                return
            if run_issue_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps([{"id": "issue-1"}]).encode())
                return
            if run_log_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"lines": []}).encode())
                return
            if workspace_ops_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"items": []}).encode())
                return
        if scenario == "api-key-ok":
            if self.path == "/api/health":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {
                            "status": "ok",
                            "deploymentMode": "authenticated",
                            "deploymentExposure": "private",
                        }
                    ).encode()
                )
                return
            if self.path == "/api/auth/get-session":
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Board authentication required"}).encode())
                return
            if run_issue_match or run_log_match or workspace_ops_match:
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Unauthorized"}).encode())
                return
            if self.path == "/api/agents/me" and auth.startswith("Bearer "):
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"id": "agent-123"}).encode())
                return
            if self.path == "/api/agents/me/inbox-lite" and auth.startswith("Bearer "):
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"items": [{"id": "issue-1"}]}).encode())
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

  trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; rm -rf "$output_dir"' RETURN
  run_expect 0 env \
    PAPERCLIP_API_URL="http://127.0.0.1:$port" \
    PAPERCLIP_AGENT_ID="agent-123" \
    PAPERCLIP_COMPANY_ID="company-123" \
    PAPERCLIP_RUN_ID="run-123" \
    PAPERCLIP_WORKSPACE_CWD="/workspace" \
    PAPERCLIP_WORKSPACE_SOURCE="agent-run" \
    PAPERCLIP_API_KEY="${PAPERCLIP_API_KEY:-}" \
    GH_TOKEN="gh-test-token" \
    CLOUD_AGENT_INJECTED_SECRET_NAMES="GH_TOKEN" \
    ./scripts/paperclip-heartbeat-next-action.sh "$output_dir" paperclip-secret cursor-secret
  LAST_HEARTBEAT_OUTPUT_DIR="$output_dir"
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
  trap - RETURN
}

run_mock_heartbeat_next_action_json() {
  local scenario="$1"
  local port server_pid output_dir
  port="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"
  output_dir="$(mktemp -d)"

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
        run_log_match = re.fullmatch(r"/api/heartbeat-runs/[^/]+/log\?offset=0&limitBytes=4096", self.path)
        workspace_ops_match = re.fullmatch(r"/api/heartbeat-runs/[^/]+/workspace-operations", self.path)
        auth = self.headers.get("Authorization", "")
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
            if run_issue_match or run_log_match or workspace_ops_match:
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Board authentication required"}).encode())
                return
        if scenario == "board-session-ok":
            if self.path == "/api/health":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {
                            "status": "ok",
                            "deploymentMode": "authenticated",
                            "deploymentExposure": "private",
                        }
                    ).encode()
                )
                return
            if self.path == "/api/auth/get-session":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"user": {"id": "user-123"}}).encode())
                return
            if run_issue_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps([{"id": "issue-1"}]).encode())
                return
            if run_log_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"lines": []}).encode())
                return
            if workspace_ops_match:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"items": []}).encode())
                return
        if scenario == "api-key-ok":
            if self.path == "/api/health":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps(
                        {
                            "status": "ok",
                            "deploymentMode": "authenticated",
                            "deploymentExposure": "private",
                        }
                    ).encode()
                )
                return
            if self.path == "/api/auth/get-session":
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Board authentication required"}).encode())
                return
            if run_issue_match or run_log_match or workspace_ops_match:
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Unauthorized"}).encode())
                return
            if self.path == "/api/agents/me" and auth.startswith("Bearer "):
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"id": "agent-123"}).encode())
                return
            if self.path == "/api/agents/me/inbox-lite" and auth.startswith("Bearer "):
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"items": [{"id": "issue-1"}]}).encode())
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

  trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; rm -rf "$output_dir"' RETURN
  run_expect 0 env \
    PAPERCLIP_API_URL="http://127.0.0.1:$port" \
    PAPERCLIP_AGENT_ID="agent-123" \
    PAPERCLIP_COMPANY_ID="company-123" \
    PAPERCLIP_RUN_ID="run-123" \
    PAPERCLIP_WORKSPACE_CWD="/workspace" \
    PAPERCLIP_WORKSPACE_SOURCE="agent-run" \
    PAPERCLIP_API_KEY="${PAPERCLIP_API_KEY:-}" \
    GH_TOKEN="gh-test-token" \
    CLOUD_AGENT_INJECTED_SECRET_NAMES="GH_TOKEN" \
    ./scripts/paperclip-heartbeat-next-action.sh --json "$output_dir" paperclip-secret cursor-secret
  LAST_HEARTBEAT_OUTPUT_DIR="$output_dir"
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

blocked_update_path="$(mktemp)"
run_expect 0 ./scripts/paperclip-write-blocked-update.sh "$blocked_update_path"
assert_stdout_contains "Wrote $blocked_update_path"
if ! grep -Fq '"status": "blocked"' "$blocked_update_path"; then
  fail "blocked update artifact missing blocked status"
fi
if ! grep -Fq 'Required action: Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env' "$blocked_update_path"; then
  fail "blocked update artifact missing standard required action"
fi
rm -f "$blocked_update_path"
pass "paperclip-write-blocked-update writes a standalone blocked payload"
cleanup_last

validation_dir="$(mktemp -d)"
./scripts/paperclip-refresh-runtime-artifacts.sh "$validation_dir" paperclip-secret cursor-secret >/dev/null
run_expect 0 ./scripts/paperclip-validate-artifacts.sh "$validation_dir"
assert_stdout_contains "Validated Paperclip artifacts in $validation_dir"
assert_stdout_contains "PASS: latest manifest schema_version is 1"
pass "paperclip-validate-artifacts validates refreshed artifacts"
cleanup_last

run_expect 0 ./scripts/paperclip-validate-artifacts.sh --json "$validation_dir"
assert_stdout_json_value "schema_version" "1"
assert_stdout_json_value "artifact_type" "paperclip_artifact_validation_result"
assert_stdout_json_value "valid" "true"
rm -rf "$validation_dir"
pass "paperclip-validate-artifacts emits JSON validation result"
cleanup_last

run_mock_runtime_check_json "degraded-health-auth-blocked"
assert_stdout_json_value "schema_version" "1"
assert_stdout_json_value "artifact_type" "paperclip_runtime_diagnosis"
assert_stdout_json_value "diagnosis" "missing_paperclip_auth"
assert_stdout_json_value "issue_operations_blocked" "true"
assert_stdout_json_value "summary.paperclip_api_key_injected" "false"
assert_stdout_json_value "summary.run_issues_with_run_header_status" "401"
assert_stdout_json_value "run_id_header_read_access" "false"
assert_stdout_json_value "summary.run_log_with_run_header_status" "401"
assert_stdout_json_value "summary.workspace_operations_with_run_header_status" "401"
assert_stdout_json_value "run_scoped_debug_read_access" "false"
assert_stdout_json_value "heartbeat_next_action_state" "refresh_blocked_artifacts"
pass "paperclip-runtime-check emits structured JSON diagnosis"
cleanup_last

run_mock_runtime_check_json "board-session-ok" 0
assert_stdout_json_value "schema_version" "1"
assert_stdout_json_value "artifact_type" "paperclip_runtime_diagnosis"
assert_stdout_json_value "diagnosis" "board_session_ok"
assert_stdout_json_value "api_helper_ready" "false"
assert_stdout_json_value "heartbeat_next_action_state" "warn_session_only"
pass "paperclip-runtime-check reports session-only next action state"
cleanup_last

PAPERCLIP_API_KEY="paperclip-test-token" run_mock_runtime_check_json "api-key-ok" 0
assert_stdout_json_value "schema_version" "1"
assert_stdout_json_value "artifact_type" "paperclip_runtime_diagnosis"
assert_stdout_json_value "diagnosis" "paperclip_api_key_ok"
assert_stdout_json_value "api_helper_ready" "true"
assert_stdout_json_value "heartbeat_next_action_state" "current_issue_playbook"
pass "paperclip-runtime-check reports API-helper-ready next action state"
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

snapshot_path="$(mktemp)"
run_expect 0 ./scripts/paperclip-write-runtime-snapshot.sh "$snapshot_path" paperclip-secret cursor-secret
assert_stdout_contains "Wrote $snapshot_path"
python3 - "$snapshot_path" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
assert data["schema_version"] == 1
assert data["artifact_type"] == "paperclip_runtime_snapshot"
assert data["runtime"]["diagnosis"] in {"missing_paperclip_auth", "health_unavailable", "unexpected_session_status", "board_session_ok", "paperclip_api_key_ok", "paperclip_api_key_rejected", "paperclip_api_key_inbox_lookup_failed", "run_issue_lookup_failed"}
assert "blocked_issue_payload" in data["unblock"]
assert "adapter_env_payload" in data["unblock"]
assert data["unblock"]["owner"] == "Paperclip operator"
PY
rm -f "$snapshot_path"
pass "paperclip-write-runtime-snapshot writes a JSON handoff snapshot"
cleanup_last

refresh_dir="$(mktemp -d)"
run_expect 0 ./scripts/paperclip-refresh-runtime-artifacts.sh "$refresh_dir" paperclip-secret cursor-secret
assert_stdout_contains "Refreshed runtime artifacts in $refresh_dir"
assert_stdout_contains "Archived runtime artifacts in $refresh_dir/history/"
if [[ ! -f "$refresh_dir/osiris-paperclip-runtime-report.md" ]]; then
  fail "refresh helper did not write markdown report"
fi
if [[ ! -f "$refresh_dir/osiris-paperclip-runtime-snapshot.json" ]]; then
  fail "refresh helper did not write json snapshot"
fi
if [[ ! -f "$refresh_dir/osiris-paperclip-blocked-update.json" ]]; then
  fail "refresh helper did not write blocked update artifact"
fi
if [[ ! -f "$refresh_dir/osiris-paperclip-runtime-latest.json" ]]; then
  fail "refresh helper did not write latest manifest"
fi
archive_dirs=("$refresh_dir"/history/*)
if [[ ! -d "${archive_dirs[0]}" ]]; then
  fail "refresh helper did not create archive directory"
fi
if [[ ! -f "${archive_dirs[0]}/osiris-paperclip-runtime-report.md" ]]; then
  fail "refresh helper did not archive markdown report"
fi
if [[ ! -f "${archive_dirs[0]}/osiris-paperclip-runtime-snapshot.json" ]]; then
  fail "refresh helper did not archive json snapshot"
fi
if [[ ! -f "${archive_dirs[0]}/osiris-paperclip-blocked-update.json" ]]; then
  fail "refresh helper did not archive blocked update artifact"
fi
if [[ ! -f "${archive_dirs[0]}/osiris-paperclip-runtime-latest.json" ]]; then
  fail "refresh helper did not archive latest manifest"
fi
python3 - "$refresh_dir/osiris-paperclip-runtime-latest.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
assert data["schema_version"] == 1
assert data["artifact_type"] == "paperclip_runtime_latest_manifest"
assert data["runtime"]["heartbeat_next_action_state"] == "refresh_blocked_artifacts"
assert data["runtime"]["issue_operations_blocked"] is True
assert data["latest"]["latest_archive_dir"]
assert data["git"]["branch"]
assert data["git"]["commit"]
assert data["latest"]["report_relative_path"]
assert data["latest"]["snapshot_relative_path"]
assert data["latest"]["blocked_update_relative_path"]
assert data["latest"]["archive_report_relative_path"]
assert data["latest"]["archive_snapshot_relative_path"]
assert data["latest"]["archive_blocked_update_relative_path"]
assert data["latest"]["archive_manifest_relative_path"]
for key in ["report", "snapshot", "blocked_update", "archive_report", "archive_snapshot", "archive_blocked_update"]:
    assert data["file_metadata"][key]["size_bytes"] > 0
    assert len(data["file_metadata"][key]["sha256"]) == 64
    assert data["file_metadata"][key]["relative_path"]
PY
rm -rf "$refresh_dir"
pass "paperclip-refresh-runtime-artifacts refreshes both runtime artifacts"
cleanup_last

refresh_json_dir="$(mktemp -d)"
run_expect 0 ./scripts/paperclip-refresh-runtime-artifacts.sh --json "$refresh_json_dir" paperclip-secret cursor-secret
assert_stdout_json_value "schema_version" "1"
assert_stdout_json_value "artifact_type" "paperclip_refresh_result"
assert_stdout_json_nonempty "latest_manifest_path"
assert_stdout_json_value "latest_manifest.artifact_type" "paperclip_runtime_latest_manifest"
python3 - "$LAST_STDOUT_FILE" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
assert data["archive_dir"]
assert data["latest_manifest"]["runtime"]["heartbeat_next_action_state"] == "refresh_blocked_artifacts"
PY
rm -rf "$refresh_json_dir"
pass "paperclip-refresh-runtime-artifacts emits JSON result"
cleanup_last

run_mock_heartbeat_next_action "degraded-health-auth-blocked"
assert_stdout_contains "Runtime diagnosis: missing_paperclip_auth"
assert_stdout_contains "Heartbeat disposition: blocked on Paperclip auth."
assert_stdout_contains "Latest manifest:"
if [[ ! -f "${LAST_HEARTBEAT_OUTPUT_DIR}/osiris-paperclip-runtime-report.md" ]]; then
  fail "next-action helper did not write markdown report"
fi
if [[ ! -f "${LAST_HEARTBEAT_OUTPUT_DIR}/osiris-paperclip-runtime-snapshot.json" ]]; then
  fail "next-action helper did not write json snapshot"
fi
if [[ ! -f "${LAST_HEARTBEAT_OUTPUT_DIR}/osiris-paperclip-blocked-update.json" ]]; then
  fail "next-action helper did not write blocked update artifact"
fi
if [[ ! -f "${LAST_HEARTBEAT_OUTPUT_DIR}/osiris-paperclip-runtime-latest.json" ]]; then
  fail "next-action helper did not write latest manifest"
fi
next_archive_dirs=("${LAST_HEARTBEAT_OUTPUT_DIR}"/history/*)
if [[ ! -d "${next_archive_dirs[0]}" ]]; then
  fail "next-action helper did not create archive directory"
fi
if [[ ! -f "${next_archive_dirs[0]}/osiris-paperclip-blocked-update.json" ]]; then
  fail "next-action helper did not archive blocked update artifact"
fi
if [[ ! -f "${next_archive_dirs[0]}/osiris-paperclip-runtime-latest.json" ]]; then
  fail "next-action helper did not archive latest manifest"
fi
rm -rf "${LAST_HEARTBEAT_OUTPUT_DIR}"
unset LAST_HEARTBEAT_OUTPUT_DIR
pass "paperclip-heartbeat-next-action handles blocked heartbeats"
cleanup_last

run_mock_heartbeat_next_action_json "degraded-health-auth-blocked"
assert_stdout_json_value "schema_version" "1"
assert_stdout_json_value "artifact_type" "paperclip_heartbeat_next_action"
assert_stdout_json_value "next_action_state" "refresh_blocked_artifacts"
assert_stdout_json_value "heartbeat_disposition" "blocked"
assert_stdout_json_nonempty "artifacts.latest_manifest_path"
assert_stdout_json_value "latest_manifest.schema_version" "1"
assert_stdout_json_value "latest_manifest.artifact_type" "paperclip_runtime_latest_manifest"
assert_stdout_json_value "blocked_update_payload.status" "blocked"
python3 - "$LAST_STDOUT_FILE" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
assert isinstance(data["recommended_commands"], list) and len(data["recommended_commands"]) >= 2
PY
rm -rf "${LAST_HEARTBEAT_OUTPUT_DIR}"
unset LAST_HEARTBEAT_OUTPUT_DIR
pass "paperclip-heartbeat-next-action emits blocked JSON result"
cleanup_last

run_mock_heartbeat_next_action "board-session-ok"
assert_stdout_contains "Runtime diagnosis: board_session_ok"
assert_stdout_contains "Heartbeat disposition: run visibility available, but Paperclip API helper is not ready."
if [[ -e "${LAST_HEARTBEAT_OUTPUT_DIR}/osiris-paperclip-runtime-report.md" ]]; then
  fail "next-action helper should not refresh blocked artifacts for session-only visibility"
fi
rm -rf "${LAST_HEARTBEAT_OUTPUT_DIR}"
unset LAST_HEARTBEAT_OUTPUT_DIR
pass "paperclip-heartbeat-next-action warns when board session exists without API helper readiness"
cleanup_last

run_mock_heartbeat_next_action_json "board-session-ok"
assert_stdout_json_value "schema_version" "1"
assert_stdout_json_value "artifact_type" "paperclip_heartbeat_next_action"
assert_stdout_json_value "next_action_state" "warn_session_only"
assert_stdout_json_value "heartbeat_disposition" "session_only"
python3 - "$LAST_STDOUT_FILE" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
assert isinstance(data["recommended_commands"], list) and len(data["recommended_commands"]) >= 2
PY
rm -rf "${LAST_HEARTBEAT_OUTPUT_DIR}"
unset LAST_HEARTBEAT_OUTPUT_DIR
pass "paperclip-heartbeat-next-action emits session-only JSON result"
cleanup_last

PAPERCLIP_API_KEY="paperclip-test-token" run_mock_heartbeat_next_action "api-key-ok"
assert_stdout_contains "Runtime diagnosis: paperclip_api_key_ok"
assert_stdout_contains "Heartbeat disposition: issue operations available via API helper."
assert_stdout_contains "issue-get-current"
if [[ -e "${LAST_HEARTBEAT_OUTPUT_DIR}/osiris-paperclip-runtime-report.md" ]]; then
  fail "next-action helper should not refresh blocked artifacts when issue operations are available"
fi
rm -rf "${LAST_HEARTBEAT_OUTPUT_DIR}"
unset LAST_HEARTBEAT_OUTPUT_DIR
pass "paperclip-heartbeat-next-action switches to current-issue playbook when API helper auth is available"
cleanup_last

PAPERCLIP_API_KEY="paperclip-test-token" run_mock_heartbeat_next_action_json "api-key-ok"
assert_stdout_json_value "schema_version" "1"
assert_stdout_json_value "artifact_type" "paperclip_heartbeat_next_action"
assert_stdout_json_value "next_action_state" "current_issue_playbook"
assert_stdout_json_value "heartbeat_disposition" "ready"
assert_stdout_json_value "playbook_command" "./scripts/paperclip-api.sh current-issue-playbook"
assert_stdout_json_nonempty "playbook_text"
python3 - "$LAST_STDOUT_FILE" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
assert isinstance(data["playbook_commands"], list) and len(data["playbook_commands"]) >= 3
assert data["recommended_commands"] == data["playbook_commands"]
PY
rm -rf "${LAST_HEARTBEAT_OUTPUT_DIR}"
unset LAST_HEARTBEAT_OUTPUT_DIR
pass "paperclip-heartbeat-next-action emits API-helper-ready JSON result"
cleanup_last

run_mock_runtime_check "degraded-health-auth-blocked"
assert_stdout_contains "\"health_status\": 503"
assert_stdout_contains "Health check did not return 200, but auth signals are sufficient to diagnose the blocker."
assert_stdout_contains "Board authentication is not available in this shell session."
assert_stdout_contains "Adding X-Paperclip-Run-Id to the run issue lookup did not unlock read access in this shell."
assert_stdout_contains "Heartbeat-run log and workspace-operation reads also remain locked in this shell."
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
