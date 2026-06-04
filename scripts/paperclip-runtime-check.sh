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
api_key = os.environ.get("PAPERCLIP_API_KEY", "").strip()
gh_token = os.environ.get("GH_TOKEN", "").strip()
aux_home_keys = [
    key for key in os.environ if key.startswith("AG") and key.endswith("_HOME")
]
aux_home = os.environ.get(aux_home_keys[0], "").strip() if aux_home_keys else ""
injected_secret_names = {
    item.strip()
    for item in os.environ.get("CLOUD_AGENT_INJECTED_SECRET_NAMES", "").split(",")
    if item.strip()
}


def request(path: str, headers: dict[str, str] | None = None):
    req = urllib.request.Request(
        f"{base}{path}",
        headers={"Accept": "application/json", **(headers or {})},
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

bearer_me_status = None
bearer_me_body = None
bearer_inbox_status = None
bearer_inbox_body = None
if api_key:
    bearer_headers = {"Authorization": f"Bearer {api_key}"}
    bearer_me_status, bearer_me_body = request("/api/agents/me", bearer_headers)
    bearer_inbox_status, bearer_inbox_body = request(
        "/api/agents/me/inbox-lite", bearer_headers
    )

summary = {
    "health_status": health_status,
    "deployment_mode": None if not isinstance(health_json, dict) else health_json.get("deploymentMode"),
    "deployment_exposure": None if not isinstance(health_json, dict) else health_json.get("deploymentExposure"),
    "session_status": session_status,
    "session_authenticated": session_status == 200,
    "run_issues_status": run_issues_status,
    "run_issues_accessible": run_issues_status == 200,
    "api_key_present": bool(api_key),
    "paperclip_api_key_injected": "PAPERCLIP_API_KEY" in injected_secret_names,
    "gh_token_present": bool(gh_token),
    "aux_home_env_present": bool(aux_home_keys),
    "aux_home_is_directory": bool(aux_home) and os.path.isdir(aux_home),
    "bearer_me_status": bearer_me_status,
    "bearer_inbox_status": bearer_inbox_status,
}

print("Paperclip runtime check")
print("=======================")
print(json.dumps(summary, indent=2))
print()

if health_status != 200:
    print("Health check failed, so the runtime is not ready for issue operations.", file=sys.stderr)
    sys.exit(1)

if run_issues_status == 200:
    issue_count = len(run_issues_json) if isinstance(run_issues_json, list) else "unknown"
    print(f"Current run issue lookup succeeded via board session ({issue_count} issue entries).")
    sys.exit(0)

if api_key:
    if bearer_me_status != 200:
        print("A bearer token is present, but Paperclip rejected agent authentication.", file=sys.stderr)
        if bearer_me_body:
            print(bearer_me_body, file=sys.stderr)
        sys.exit(3)

    if bearer_inbox_status != 200:
        print("Bearer auth succeeded for /api/agents/me, but inbox lookup still failed.", file=sys.stderr)
        if bearer_inbox_body:
            print(bearer_inbox_body, file=sys.stderr)
        sys.exit(3)

    inbox_json = parse_json(bearer_inbox_body)
    issue_count = len(inbox_json) if isinstance(inbox_json, list) else len((inbox_json or {}).get("items", []))
    print(f"Current issue lookup succeeded via PAPERCLIP_API_KEY ({issue_count} issue entries).")
    sys.exit(0)

if session_status == 401:
    error = None if not isinstance(session_json, dict) else session_json.get("error")
    print("Board authentication is not available in this shell session.")
    if error:
        print(f"Server response: {error}")
    if gh_token:
        print("GH_TOKEN is present for GitHub operations, but it cannot authenticate Paperclip issue endpoints.")
    if aux_home and not os.path.isdir(aux_home):
        print("An auxiliary agent-home env var is present in runtime metadata, but it is not a readable directory in this shell.")
        print("Do not rely on that env var as a fallback source for current issue or comment context here.")
    if "PAPERCLIP_API_KEY" not in injected_secret_names:
        print(
            "The runtime metadata shows that PAPERCLIP_API_KEY was not injected into this cloud shell."
        )
        print(
            "Unblock owner: Paperclip operator\n"
            "Required action: inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env."
        )
    print(
        "Issue reads, comments, interactions, and disposition updates will fail "
        "until a board-authenticated session or PAPERCLIP_API_KEY is available."
    )
    sys.exit(2)

if session_status != 200:
    print("Session check returned an unexpected status.", file=sys.stderr)
    print(session_body, file=sys.stderr)
    sys.exit(1)

print("The shell is authenticated, but current-run issue lookup still failed.", file=sys.stderr)
if isinstance(run_issues_json, dict) and run_issues_json.get("error"):
    print(run_issues_json["error"], file=sys.stderr)
else:
    print(run_issues_body, file=sys.stderr)
sys.exit(1)
PY
