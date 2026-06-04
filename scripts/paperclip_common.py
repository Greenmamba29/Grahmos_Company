#!/usr/bin/env python3

import json
import os
import subprocess
import sys
import urllib.parse


ACTIVE_STATUSES = {"backlog", "todo", "in_progress", "in_review", "blocked"}


def run_api(
    method: str,
    path: str,
    body: dict | None = None,
    *,
    print_errors: bool = True,
):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    helper = os.path.join(script_dir, "paperclip-api")
    cmd = [helper, method, path]
    if body is not None:
        cmd.append(json.dumps(body))
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        if print_errors:
            sys.stderr.write(proc.stderr or proc.stdout)
        raise SystemExit(proc.returncode)
    if not proc.stdout.strip():
        return None
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        sys.stdout.write(proc.stdout)
        return None


def resolve_issue_id(explicit_issue_id: str | None) -> str:
    if explicit_issue_id:
        return explicit_issue_id

    company_id = os.environ.get("PAPERCLIP_COMPANY_ID")
    agent_id = os.environ.get("PAPERCLIP_AGENT_ID")
    if not company_id or not agent_id:
        raise SystemExit("error: PAPERCLIP_COMPANY_ID and PAPERCLIP_AGENT_ID are required")

    query = urllib.parse.urlencode(
        {
            "assigneeAgentId": agent_id,
            "limit": 20,
            "sortField": "updatedAt",
            "sortDir": "desc",
        }
    )
    issues = run_api("GET", f"/companies/{company_id}/issues?{query}") or []
    active = [issue for issue in issues if issue.get("status") in ACTIVE_STATUSES]

    if len(active) == 1:
        return active[0]["id"]

    if not active:
        raise SystemExit("error: no active assigned issue found; pass --issue-id explicitly")

    sys.stderr.write("error: multiple active assigned issues found; pass --issue-id explicitly\n")
    for issue in active:
        identifier = issue.get("identifier") or issue.get("id")
        title = issue.get("title") or "<untitled>"
        status = issue.get("status") or "unknown"
        sys.stderr.write(f"  - {identifier} [{status}] {title}\n")
    raise SystemExit(66)
