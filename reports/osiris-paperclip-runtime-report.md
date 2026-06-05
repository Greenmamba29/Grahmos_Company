# Osiris Hermes Paperclip Runtime Report

- Generated at: 2026-06-05T23:49:06Z
- Git branch: cursor/paperclip-runtime-tooling-82aa
- Git commit: 5edb203a4e556cb4b555f8f0b25c2aab074b31d8
- Runtime check exit code: 2
- Operator handoff exit code: 0

## Runtime check output

```text
Paperclip runtime check
=======================
{
  "health_status": 200,
  "deployment_mode": "authenticated",
  "deployment_exposure": "private",
  "session_status": 401,
  "session_authenticated": false,
  "run_issues_status": 401,
  "run_issues_accessible": false,
  "run_issues_with_run_header_status": 401,
  "run_id_header_read_access": false,
  "run_log_with_run_header_status": 401,
  "workspace_operations_with_run_header_status": 401,
  "run_scoped_debug_read_access": false,
  "api_helper_ready": false,
  "api_key_present": false,
  "paperclip_api_key_injected": false,
  "gh_token_present": true,
  "aux_home_env_present": true,
  "aux_home_is_directory": false,
  "bearer_me_status": null,
  "bearer_inbox_status": null
}

Board authentication is not available in this shell session.
Server response: Board authentication required
GH_TOKEN is present for GitHub operations, but it cannot authenticate Paperclip issue endpoints.
An auxiliary agent-home env var is present in runtime metadata, but it is not a readable directory in this shell.
Do not rely on that env var as a fallback source for current issue or comment context here.
Adding X-Paperclip-Run-Id to the run issue lookup did not unlock read access in this shell.
Heartbeat-run log and workspace-operation reads also remain locked in this shell.
The runtime metadata shows that PAPERCLIP_API_KEY was not injected into this cloud shell.
Unblock owner: Paperclip operator
Required action: inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env.
Next helper commands:
  ./scripts/paperclip-api.sh adapter-env-template YOUR_PAPERCLIP_SECRET_ID [YOUR_CURSOR_SECRET_ID]
  ./scripts/paperclip-runtime-check.sh
  ./scripts/paperclip-api.sh current-issue-playbook
Issue reads, comments, interactions, and disposition updates will fail until a board-authenticated session or PAPERCLIP_API_KEY is available.
```

## Operator unblock handoff

```text
Paperclip Cursor Cloud unblock handoff
======================================

Use this when ./scripts/paperclip-runtime-check.sh reports that:
- board authentication is unavailable in the shell
- PAPERCLIP_API_KEY is not present
- CLOUD_AGENT_INJECTED_SECRET_NAMES does not include PAPERCLIP_API_KEY

Blocked issue payload
---------------------
{
  "status": "blocked",
  "comment": "Blocked.\n\nUnblock owner: Paperclip operator\nRequired action: Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env\n\nDetails: Current Cursor Cloud shell has no board-authenticated Paperclip session and no injected PAPERCLIP_API_KEY. After the env change, rerun the heartbeat and continue the current issue with resume=true."
}

Adapter env payload
-------------------
{
  "adapterConfig": {
    "env": {
      "CURSOR_API_KEY": {
        "secretId": "cursor-api-key-secret-id",
        "type": "secret_ref",
        "version": "latest"
      },
      "PAPERCLIP_API_KEY": {
        "secretId": "osiris-paperclip-agent-key-secret-id",
        "type": "secret_ref",
        "version": "latest"
      }
    }
  },
  "adapterType": "cursor_cloud"
}

Replay commands after the adapter env update
--------------------------------------------
./scripts/paperclip-runtime-check.sh
./scripts/paperclip-api.sh current-issue-playbook

Recommended first issue update after auth is fixed
--------------------------------------------------
./scripts/paperclip-api.sh issue-comment-current-template "Resuming with Cursor Cloud Paperclip auth fixed." true
```
