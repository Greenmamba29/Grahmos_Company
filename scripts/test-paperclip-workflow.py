#!/usr/bin/env python3

import json
import os
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


class MockPaperclipHandler(BaseHTTPRequestHandler):
    server_version = "MockPaperclip/1.0"

    def _read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return None
        raw = self.rfile.read(length)
        if not raw:
            return None
        return json.loads(raw.decode("utf-8"))

    def _write_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _record(self, method, path, payload=None):
        self.server.calls.append(
            {
                "method": method,
                "path": path,
                "payload": payload,
            }
        )

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        self._record("GET", self.path)

        if path == "/api/auth/get-session":
            if self.server.mode == "blocked":
                self._write_json(401, {"error": "Board authentication required"})
                return
            self._write_json(200, {"user": {"id": "user-1", "email": "agent@example.com"}})
            return

        if path.startswith("/api/heartbeat-runs/"):
            if self.server.mode == "blocked":
                self._write_json(401, {"error": "Unauthorized"})
                return
            self._write_json(200, {"id": path.rsplit("/", 1)[-1], "status": "running"})
            return

        if path.startswith("/api/companies/") and path.endswith("/issues"):
            if self.server.mode == "blocked":
                self._write_json(401, {"error": "Unauthorized"})
                return
            query = parse_qs(parsed.query)
            self._write_json(
                200,
                {
                    "items": [
                        {
                            "id": "issue-1",
                            "executionWorkspaceId": query.get("executionWorkspaceId", [None])[0],
                        }
                    ]
                },
            )
            return

        self._write_json(404, {"error": f"Unhandled GET {self.path}"})

    def do_POST(self):
        payload = self._read_json()
        self._record("POST", self.path, payload)

        if self.path.startswith("/api/issues/") and self.path.endswith("/comments"):
            self._write_json(201, {"id": "comment-1", "body": payload.get("body", "") if payload else ""})
            return

        self._write_json(404, {"error": f"Unhandled POST {self.path}"})

    def do_PATCH(self):
        payload = self._read_json()
        self._record("PATCH", self.path, payload)

        if self.path.startswith("/api/issues/"):
            self._write_json(200, {"id": self.path.rsplit("/", 1)[-1], **(payload or {})})
            return

        self._write_json(404, {"error": f"Unhandled PATCH {self.path}"})

    def log_message(self, format, *args):
        return


class MockPaperclipServer(ThreadingHTTPServer):
    def __init__(self, server_address, mode):
        super().__init__(server_address, MockPaperclipHandler)
        self.mode = mode
        self.calls = []


def run(cmd, env):
    return subprocess.run(cmd, text=True, capture_output=True, env=env, check=False)


def build_env(api_url):
    env = os.environ.copy()
    env.update(
        {
            "PAPERCLIP_API_URL": api_url,
            "PAPERCLIP_COMPANY_ID": "company-123",
            "PAPERCLIP_RUN_ID": "run-123",
            "PAPERCLIP_WORKSPACE_CWD": "/paperclip/instances/default/workspaces/workspace-123",
            "PAPERCLIP_WORKSPACE_SOURCE": "mock_source",
            "PAPERCLIP_AGENT_ID": "agent-123",
        }
    )
    return env


def assert_true(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        cookie_jar = Path(tmp) / "cookies.txt"
        cookie_jar.write_text("")

        blocked_server = MockPaperclipServer(("127.0.0.1", 0), "blocked")
        blocked_thread = threading.Thread(target=blocked_server.serve_forever, daemon=True)
        blocked_thread.start()
        blocked_url = f"http://127.0.0.1:{blocked_server.server_port}"

        authenticated_server = MockPaperclipServer(("127.0.0.1", 0), "authenticated")
        authenticated_thread = threading.Thread(target=authenticated_server.serve_forever, daemon=True)
        authenticated_thread.start()
        authenticated_url = f"http://127.0.0.1:{authenticated_server.server_port}"

        try:
            blocked_env = build_env(blocked_url)
            auth_env = build_env(authenticated_url)

            probe_blocked = run(["/workspace/scripts/paperclip-auth-probe.sh"], blocked_env)
            assert_true(probe_blocked.returncode == 3, f"expected blocked probe exit 3, got {probe_blocked.returncode}")
            assert_true("Result: BLOCKED" in probe_blocked.stdout, "blocked probe output missing BLOCKED result")

            finalize_blocked = run(
                [
                    "/workspace/scripts/paperclip-finalize-blocked.sh",
                    "--issue-id",
                    "ISSUE-1",
                    "--cookie-jar",
                    str(cookie_jar),
                    "--dry-run",
                ],
                blocked_env,
            )
            assert_true(finalize_blocked.returncode == 3, f"expected blocked finalizer exit 3, got {finalize_blocked.returncode}")
            blocked_non_get = [call for call in blocked_server.calls if call["method"] != "GET"]
            assert_true(not blocked_non_get, f"blocked flow should not send mutations, saw {blocked_non_get}")

            finalize_auth = run(
                [
                    "/workspace/scripts/paperclip-finalize-blocked.sh",
                    "--issue-id",
                    "ISSUE-2",
                    "--cookie-jar",
                    str(cookie_jar),
                    "--evidence",
                    "Mock authenticated workflow",
                ],
                auth_env,
            )
            assert_true(finalize_auth.returncode == 0, f"expected authenticated finalizer exit 0, got {finalize_auth.returncode}")

            auth_posts = [call for call in authenticated_server.calls if call["method"] == "POST"]
            auth_patches = [call for call in authenticated_server.calls if call["method"] == "PATCH"]
            assert_true(len(auth_posts) == 1, f"expected one POST comment call, saw {auth_posts}")
            assert_true(len(auth_patches) == 1, f"expected one PATCH status call, saw {auth_patches}")
            assert_true(
                auth_posts[0]["path"] == "/api/issues/ISSUE-2/comments",
                f"unexpected comment path {auth_posts[0]['path']}",
            )
            assert_true(
                auth_patches[0]["path"] == "/api/issues/ISSUE-2",
                f"unexpected status path {auth_patches[0]['path']}",
            )
            assert_true(
                auth_patches[0]["payload"] == {"status": "blocked"},
                f"unexpected status payload {auth_patches[0]['payload']}",
            )
            assert_true(
                "Unblock owner: Paperclip board admin/operator" in auth_posts[0]["payload"]["body"],
                "comment payload missing unblock owner",
            )
            assert_true(
                "Mock authenticated workflow" in auth_posts[0]["payload"]["body"],
                "comment payload missing evidence line",
            )

            print("PASS: blocked and authenticated Paperclip workflows behave as expected.")
        finally:
            blocked_server.shutdown()
            authenticated_server.shutdown()
            blocked_server.server_close()
            authenticated_server.server_close()


if __name__ == "__main__":
    main()
