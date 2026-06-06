#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-runtime-check.sh [--json]

Options:
  --json   Print a machine-readable JSON diagnosis payload instead of prose.
EOF
}

json_mode=0
case "${1:-}" in
  "")
    ;;
  --json)
    json_mode=1
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "error: unknown argument: ${1:-}" >&2
    usage >&2
    exit 2
    ;;
esac

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

python3 - "$json_mode" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

json_mode = sys.argv[1] == "1"
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
run_issues_with_header_status, run_issues_with_header_body = request(
    f"/api/heartbeat-runs/{run_id}/issues",
    {"X-Paperclip-Run-Id": run_id},
)
run_log_with_header_status, run_log_with_header_body = request(
    f"/api/heartbeat-runs/{run_id}/log?offset=0&limitBytes=4096",
    {"X-Paperclip-Run-Id": run_id},
)
workspace_ops_with_header_status, workspace_ops_with_header_body = request(
    f"/api/heartbeat-runs/{run_id}/workspace-operations",
    {"X-Paperclip-Run-Id": run_id},
)

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
    "run_issues_with_run_header_status": run_issues_with_header_status,
    "run_id_header_read_access": run_issues_with_header_status == 200,
    "run_log_with_run_header_status": run_log_with_header_status,
    "workspace_operations_with_run_header_status": workspace_ops_with_header_status,
    "run_scoped_debug_read_access": (
        run_issues_with_header_status == 200
        or run_log_with_header_status == 200
        or workspace_ops_with_header_status == 200
    ),
    "api_helper_ready": bearer_me_status == 200 and bearer_inbox_status == 200,
    "api_key_present": bool(api_key),
    "paperclip_api_key_injected": "PAPERCLIP_API_KEY" in injected_secret_names,
    "gh_token_present": bool(gh_token),
    "aux_home_env_present": bool(aux_home_keys),
    "aux_home_is_directory": bool(aux_home) and os.path.isdir(aux_home),
    "bearer_me_status": bearer_me_status,
    "bearer_inbox_status": bearer_inbox_status,
}

unblock_owner = "Paperclip operator"
required_action = "inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env."
next_helper_commands = [
    "./scripts/paperclip-api.sh adapter-env-template YOUR_PAPERCLIP_SECRET_ID [YOUR_CURSOR_SECRET_ID]",
    "./scripts/paperclip-runtime-check.sh",
    "./scripts/paperclip-api.sh current-issue-playbook",
]


def emit_json(payload: dict, exit_code: int):
    payload = {
        "schema_version": 1,
        "artifact_type": "paperclip_runtime_diagnosis",
        "summary": summary,
        "exit_code": exit_code,
        **payload,
    }
    json.dump(payload, sys.stdout, indent=2)
    sys.stdout.write("\n")
    raise SystemExit(exit_code)


if not json_mode:
    print("Paperclip runtime check")
    print("=======================")
    print(json.dumps(summary, indent=2))
    print()

if run_issues_status == 200:
    issue_count = len(run_issues_json) if isinstance(run_issues_json, list) else "unknown"
    if json_mode:
        emit_json(
            {
                "diagnosis": "board_session_ok",
                "issue_operations_blocked": False,
                "access_path": "board_session",
                "issue_count": issue_count,
                "api_helper_ready": bearer_me_status == 200 and bearer_inbox_status == 200,
                "heartbeat_next_action_state": (
                    "current_issue_playbook"
                    if (bearer_me_status == 200 and bearer_inbox_status == 200)
                    else "warn_session_only"
                ),
            },
            0,
        )
    print(f"Current run issue lookup succeeded via board session ({issue_count} issue entries).")
    if not (bearer_me_status == 200 and bearer_inbox_status == 200):
        print("Run-scoped issue visibility is available, but shell issue helpers still need PAPERCLIP_API_KEY.")
    sys.exit(0)

if api_key:
    if bearer_me_status != 200:
        if json_mode:
            emit_json(
                {
                    "diagnosis": "paperclip_api_key_rejected",
                    "issue_operations_blocked": True,
                    "access_path": "paperclip_api_key",
                    "bearer_me_body": bearer_me_body,
                    "heartbeat_next_action_state": "refresh_blocked_artifacts",
                },
                3,
            )
        print("A bearer token is present, but Paperclip rejected agent authentication.", file=sys.stderr)
        if bearer_me_body:
            print(bearer_me_body, file=sys.stderr)
        sys.exit(3)

    if bearer_inbox_status != 200:
        if json_mode:
            emit_json(
                {
                    "diagnosis": "paperclip_api_key_inbox_lookup_failed",
                    "issue_operations_blocked": True,
                    "access_path": "paperclip_api_key",
                    "bearer_inbox_body": bearer_inbox_body,
                    "heartbeat_next_action_state": "refresh_blocked_artifacts",
                },
                3,
            )
        print("Bearer auth succeeded for /api/agents/me, but inbox lookup still failed.", file=sys.stderr)
        if bearer_inbox_body:
            print(bearer_inbox_body, file=sys.stderr)
        sys.exit(3)

    inbox_json = parse_json(bearer_inbox_body)
    issue_count = len(inbox_json) if isinstance(inbox_json, list) else len((inbox_json or {}).get("items", []))
    if json_mode:
        emit_json(
            {
                "diagnosis": "paperclip_api_key_ok",
                "issue_operations_blocked": False,
                "access_path": "paperclip_api_key",
                "issue_count": issue_count,
                "api_helper_ready": True,
                "heartbeat_next_action_state": "current_issue_playbook",
            },
            0,
        )
    print(f"Current issue lookup succeeded via PAPERCLIP_API_KEY ({issue_count} issue entries).")
    sys.exit(0)

if session_status == 401:
    error = None if not isinstance(session_json, dict) else session_json.get("error")
    if json_mode:
        emit_json(
            {
                "diagnosis": "missing_paperclip_auth",
                "issue_operations_blocked": True,
                "server_response": error,
                "health_probe_detail": health_body if health_status != 200 else None,
                "gh_token_warning": bool(gh_token),
                "aux_home_warning": bool(aux_home) and not os.path.isdir(aux_home),
                "paperclip_api_key_injected": "PAPERCLIP_API_KEY" in injected_secret_names,
                "run_id_header_read_access": run_issues_with_header_status == 200,
                "run_scoped_debug_read_access": (
                    run_issues_with_header_status == 200
                    or run_log_with_header_status == 200
                    or workspace_ops_with_header_status == 200
                ),
                "heartbeat_next_action_state": "refresh_blocked_artifacts",
                "unblock_owner": unblock_owner,
                "required_action": required_action,
                "next_helper_commands": next_helper_commands,
            },
            2,
        )
    if health_status != 200:
        print("Health check did not return 200, but auth signals are sufficient to diagnose the blocker.")
        if health_body:
            print(f"Health probe detail: {health_body}")
    print("Board authentication is not available in this shell session.")
    if error:
        print(f"Server response: {error}")
    if gh_token:
        print("GH_TOKEN is present for GitHub operations, but it cannot authenticate Paperclip issue endpoints.")
    if aux_home and not os.path.isdir(aux_home):
        print("An auxiliary agent-home env var is present in runtime metadata, but it is not a readable directory in this shell.")
        print("Do not rely on that env var as a fallback source for current issue or comment context here.")
    if run_issues_with_header_status != 200:
        print("Adding X-Paperclip-Run-Id to the run issue lookup did not unlock read access in this shell.")
    if run_log_with_header_status != 200 or workspace_ops_with_header_status != 200:
        print("Heartbeat-run log and workspace-operation reads also remain locked in this shell.")
    if "PAPERCLIP_API_KEY" not in injected_secret_names:
        print(
            "The runtime metadata shows that PAPERCLIP_API_KEY was not injected into this cloud shell."
        )
        print(
            "Unblock owner: Paperclip operator\n"
            "Required action: inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env."
        )
        print(
            "Next helper commands:\n"
            "  ./scripts/paperclip-api.sh adapter-env-template YOUR_PAPERCLIP_SECRET_ID [YOUR_CURSOR_SECRET_ID]\n"
            "  ./scripts/paperclip-runtime-check.sh\n"
            "  ./scripts/paperclip-api.sh current-issue-playbook"
        )
    print(
        "Issue reads, comments, interactions, and disposition updates will fail "
        "until a board-authenticated session or PAPERCLIP_API_KEY is available."
    )
    sys.exit(2)

if health_status != 200:
    if json_mode:
        emit_json(
            {
                "diagnosis": "health_unavailable",
                "issue_operations_blocked": True,
                "health_probe_detail": health_body,
                "heartbeat_next_action_state": "refresh_blocked_artifacts",
            },
            1,
        )
    print("Health check failed, so the runtime is not ready for issue operations.", file=sys.stderr)
    if health_body:
        print(health_body, file=sys.stderr)
    sys.exit(1)

if session_status != 200:
    if json_mode:
        emit_json(
            {
                "diagnosis": "unexpected_session_status",
                "issue_operations_blocked": True,
                "session_body": session_body,
                "heartbeat_next_action_state": "refresh_blocked_artifacts",
            },
            1,
        )
    print("Session check returned an unexpected status.", file=sys.stderr)
    print(session_body, file=sys.stderr)
    sys.exit(1)

if json_mode:
    emit_json(
        {
            "diagnosis": "run_issue_lookup_failed",
            "issue_operations_blocked": True,
            "run_issues_body": run_issues_body,
            "heartbeat_next_action_state": "refresh_blocked_artifacts",
        },
        1,
    )

print("The shell is authenticated, but current-run issue lookup still failed.", file=sys.stderr)
if isinstance(run_issues_json, dict) and run_issues_json.get("error"):
    print(run_issues_json["error"], file=sys.stderr)
else:
    print(run_issues_body, file=sys.stderr)
sys.exit(1)
PY
