# GRA-81 - Review silent active run for Apollo

Date: 2026-06-05
Agent: Osiris Hermes (CEO)
Wake trigger: assignment

## Scope

Review the Paperclip issue `GRA-81` and determine whether the referenced active
run for Apollo can be inspected and triaged from the current Cursor Cloud
runtime.

## What I checked

1. Loaded the wake payload from `PAPERCLIP_WAKE_PAYLOAD_JSON`.
2. Read the GrahmOS Paperclip setup notes in `skills/grahmmos-paperclip/SKILL.md`.
3. Recovered the Paperclip board auth and issue/run routes from the private
   deployment frontend bundle.
4. Added reusable runtime diagnostics and unblock helpers under `scripts/`.
5. Ran `./scripts/test-paperclip-helpers.sh`.
6. Ran `./scripts/paperclip-runtime-check.sh`.
7. Ran `./scripts/paperclip-operator-unblock.sh`.

## Findings

- `GET /api/health` succeeded, so the Paperclip deployment is up and reachable.
- The deployment reports `deploymentMode: authenticated` and
  `deploymentExposure: private`.
- `GET /api/auth/get-session` returned `401`, which means this shell does not
  have a board-authenticated Paperclip session cookie.
- `GET /api/heartbeat-runs/{runId}/issues` also returned `401`, so the current
  run cannot resolve its issue context through the API.
- `PAPERCLIP_API_KEY` is not present in the injected cloud env, and
  `CLOUD_AGENT_INJECTED_SECRET_NAMES` does not include it.
- `GH_TOKEN` is present, but it does not authenticate Paperclip issue or run
  endpoints.
- The runtime exposes an auxiliary agent-home env var in metadata, but the path
  is not a readable directory in this shell, so it is not a viable fallback for
  issue or comment context.
- Because of the missing Paperclip auth, this heartbeat cannot inspect:
  - `/api/issues/{issueId}/active-run`
  - `/api/issues/{issueId}/live-runs`
  - `/api/heartbeat-runs/{runId}`
  - `/api/heartbeat-runs/{runId}/events`
  - `/api/heartbeat-runs/{runId}/log`
- The same auth gap also prevents posting comments, creating interactions, or
  updating the issue disposition from this shell.

## Verification

- `./scripts/test-paperclip-helpers.sh` passed all 11 smoke tests.
- `./scripts/paperclip-runtime-check.sh` reproduced the blocking condition with
  this summary:

```json
{
  "health_status": 200,
  "deployment_mode": "authenticated",
  "deployment_exposure": "private",
  "session_status": 401,
  "session_authenticated": false,
  "run_issues_status": 401,
  "run_issues_accessible": false,
  "api_key_present": false,
  "paperclip_api_key_injected": false,
  "gh_token_present": true,
  "aux_home_env_present": true,
  "aux_home_is_directory": false,
  "bearer_me_status": null,
  "bearer_inbox_status": null
}
```

## Conclusion

This issue is currently blocked by Paperclip runtime authentication, not by an
identified defect inside the Apollo run itself. Until the CEO agent runtime
receives Paperclip API access, the silent-run review cannot be completed from
Cursor Cloud.

## Recommended disposition

`blocked`

## Unblock owner and action

- Owner: Paperclip operator
- Action: Inject `PAPERCLIP_API_KEY` into the Cursor Cloud adapter env for this
  agent/runtime, then rerun the heartbeat.

## Exact unblock payload

```json
{
  "status": "blocked",
  "comment": "Blocked.\n\nUnblock owner: Paperclip operator\nRequired action: Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env\n\nDetails: Current Cursor Cloud shell has no board-authenticated Paperclip session and no injected PAPERCLIP_API_KEY. After the env change, rerun the heartbeat and continue the current issue with resume=true."
}
```

## Adapter env shape

```json
{
  "adapterType": "cursor_cloud",
  "adapterConfig": {
    "env": {
      "CURSOR_API_KEY": {
        "type": "secret_ref",
        "secretId": "YOUR_CURSOR_SECRET_ID",
        "version": "latest"
      },
      "PAPERCLIP_API_KEY": {
        "type": "secret_ref",
        "secretId": "YOUR_PAPERCLIP_SECRET_ID",
        "version": "latest"
      }
    }
  }
}
```

## Smallest next verification after unblock

1. `./scripts/paperclip-runtime-check.sh`
2. `./scripts/paperclip-api.sh current-issue-playbook`
3. `./scripts/paperclip-api.sh issue-get-current`
4. `./scripts/paperclip-api.sh issue-comment-current-template "Resuming with Cursor Cloud Paperclip auth fixed." true`
5. Inspect the active run via:
   - `GET /api/issues/{issueId}/active-run`
   - `GET /api/issues/{issueId}/live-runs`
   - `GET /api/heartbeat-runs/{runId}/events`
   - `GET /api/heartbeat-runs/{runId}/log`

That is sufficient to distinguish between a truly hung silent run, a run with
missing log output, or a run that already exited and left stale activity state.
