#!/usr/bin/env bash
set -euo pipefail

unblock_owner="${1:-Paperclip operator / Osiris Hermes}"
required_action="${2:-Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env so it appears in CLOUD_AGENT_INJECTED_SECRET_NAMES.}"

python3 - "$unblock_owner" "$required_action" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

owner = sys.argv[1].strip()
action = sys.argv[2].strip()

base = os.environ.get("PAPERCLIP_API_URL", "").rstrip("/")
run_id = os.environ.get("PAPERCLIP_RUN_ID", "").strip()
api_key_present = bool(os.environ.get("PAPERCLIP_API_KEY", "").strip())
all_secret_names = [
    item.strip()
    for item in os.environ.get("CLOUD_AGENT_ALL_SECRET_NAMES", "").split(",")
    if item.strip()
]
injected_secret_names = [
    item.strip()
    for item in os.environ.get("CLOUD_AGENT_INJECTED_SECRET_NAMES", "").split(",")
    if item.strip()
]


def request(path: str):
    if not base:
        return None, "PAPERCLIP_API_URL not set"

    req = urllib.request.Request(
        f"{base}{path}",
        headers={"Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.status, response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", "replace")
    except Exception as exc:  # pragma: no cover - defensive diagnostic output
        return None, str(exc)


def summarize_body(text: str | None) -> str | None:
    if not text:
        return None
    stripped = text.strip()
    if not stripped:
        return None
    if len(stripped) <= 160:
        return stripped
    return stripped[:157] + "..."


session_status, session_body = request("/api/auth/get-session")
run_issues_status, run_issues_body = (
    request(f"/api/heartbeat-runs/{run_id}/issues") if run_id else (None, "PAPERCLIP_RUN_ID not set")
)

details = [
    f"- Session status: {session_status if session_status is not None else 'unavailable'}",
    f"- Run issues status: {run_issues_status if run_issues_status is not None else 'unavailable'}",
    f"- PAPERCLIP_API_KEY present: {'yes' if api_key_present else 'no'}",
]

if all_secret_names:
    details.append(
        "- PAPERCLIP_API_KEY listed in CLOUD_AGENT_ALL_SECRET_NAMES: "
        + ("yes" if "PAPERCLIP_API_KEY" in all_secret_names else "no")
    )

if injected_secret_names:
    details.append(
        "- PAPERCLIP_API_KEY listed in CLOUD_AGENT_INJECTED_SECRET_NAMES: "
        + ("yes" if "PAPERCLIP_API_KEY" in injected_secret_names else "no")
    )

session_summary = summarize_body(session_body)
run_issues_summary = summarize_body(run_issues_body)
if session_summary:
    details.append(f"- Session response: {session_summary}")
if run_issues_summary:
    details.append(f"- Run issues response: {run_issues_summary}")

comment = (
    "Blocked.\n\n"
    f"Unblock owner: {owner}\n"
    f"Required action: {action}\n\n"
    "Runtime evidence:\n"
    + "\n".join(details)
)

json.dump({"status": "blocked", "comment": comment}, sys.stdout, indent=2)
sys.stdout.write("\n")
PY
