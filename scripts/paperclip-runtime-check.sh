#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  PAPERCLIP_API_URL
  PAPERCLIP_AGENT_ID
  PAPERCLIP_COMPANY_ID
  PAPERCLIP_RUN_ID
  PAPERCLIP_WORKSPACE_CWD
  PAPERCLIP_WORKSPACE_SOURCE
)

missing=()
for name in "${required_vars[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    missing+=("$name")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'Missing required environment variables: %s\n' "${missing[*]}" >&2
  exit 1
fi

python3 - <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

base = os.environ["PAPERCLIP_API_URL"].rstrip("/")
run_id = os.environ["PAPERCLIP_RUN_ID"]


def request(path: str):
    req = urllib.request.Request(
        f"{base}{path}",
        headers={"Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            body = response.read().decode("utf-8", "replace")
            return response.status, body
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", "replace")
    except Exception as exc:  # pragma: no cover - defensive shell diagnostic
        return None, str(exc)


def parse_json(text: str):
    try:
        return json.loads(text)
    except Exception:
        return None


health_status, health_body = request("/api/health")
session_status, session_body = request("/api/auth/get-session")
run_issues_status, run_issues_body = request(f"/api/heartbeat-runs/{run_id}/issues")

health_json = parse_json(health_body) if health_status == 200 else None
session_json = parse_json(session_body)
run_issues_json = parse_json(run_issues_body)

summary = {
    "health_status": health_status,
    "deployment_mode": None if not isinstance(health_json, dict) else health_json.get("deploymentMode"),
    "deployment_exposure": None if not isinstance(health_json, dict) else health_json.get("deploymentExposure"),
    "session_status": session_status,
    "session_authenticated": session_status == 200,
    "run_issues_status": run_issues_status,
    "run_issues_accessible": run_issues_status == 200,
}

print("Paperclip runtime check")
print("=======================")
print(json.dumps(summary, indent=2))
print()

if health_status != 200:
    print("Health check failed, so the runtime is not ready for issue operations.", file=sys.stderr)
    sys.exit(1)

if session_status == 401:
    error = None if not isinstance(session_json, dict) else session_json.get("error")
    print("Board authentication is not available in this shell session.")
    if error:
        print(f"Server response: {error}")
    print(
        "Issue reads, comments, interactions, and disposition updates will fail "
        "until a board-authenticated session is available."
    )
    sys.exit(2)

if session_status != 200:
    print("Session check returned an unexpected status.", file=sys.stderr)
    print(session_body, file=sys.stderr)
    sys.exit(1)

if run_issues_status != 200:
    print("The shell is authenticated, but current-run issue lookup still failed.", file=sys.stderr)
    if isinstance(run_issues_json, dict) and run_issues_json.get("error"):
        print(run_issues_json["error"], file=sys.stderr)
    else:
        print(run_issues_body, file=sys.stderr)
    sys.exit(1)

issue_count = len(run_issues_json) if isinstance(run_issues_json, list) else "unknown"
print(f"Current run issue lookup succeeded ({issue_count} issue entries).")
PY
