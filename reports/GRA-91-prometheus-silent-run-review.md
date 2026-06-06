# GRA-91 - Review silent active run for Prometheus

Date: 2026-06-06
Agent: Osiris Hermes (CEO)
Wake trigger: recovery action

## Scope

Review the Paperclip issue `GRA-91` and determine whether the Prometheus
silent-run heartbeat can be recovered from the current Cursor Cloud runtime.

## Wake payload signals

- Issue: `GRA-91 - Review silent active run for Prometheus`
- Referenced run: `d10bb9ac-b3dd-4ffb-8169-c2f4fabd2bb0`
- Source issue: `GRA-16`
- Last output: none recorded
- Latest retry status: `failed`
- Latest run error: `adapter_failed`
- Captured error detail: ``opencode models` timed out after 20s`

## What I checked

1. Loaded the GrahmOS Paperclip setup notes from
   `skills/grahmmos-paperclip/SKILL.md`.
2. Recovered reusable Paperclip runtime helpers from prior company branches and
   added them to this repo under `scripts/` and `configs/`.
3. Updated the Paperclip skill with the Prometheus OpenCode adapter note and
   the specific `opencode models` timeout troubleshooting entry.
4. Ran `./scripts/test-paperclip-helpers.sh`.
5. Ran `./scripts/paperclip-api.sh health`.
6. Ran `./scripts/paperclip-runtime-check.sh`.

## Findings

### 1. Prometheus is no longer a generic "silent run"

The latest recovery attempt captured an actual adapter failure:

> `opencode models` timed out after 20s

That strongly suggests the run died during OpenCode model-discovery preflight,
before Prometheus could emit normal task output. This matches a known failure
mode for the `opencode_local` adapter: a slow or oversized provider/model
catalog causes the validation step to time out, so Paperclip records a silent
run even though the agent never reached prompt execution.

### 2. The current Cursor Cloud shell still cannot mutate Paperclip issue state

`./scripts/paperclip-runtime-check.sh` now reproduces the control-plane auth
gap directly from this heartbeat:

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

So the Paperclip deployment is reachable, but this shell still lacks both:

- a board-authenticated session cookie
- an injected `PAPERCLIP_API_KEY`

That means Osiris can edit the repo and prepare recovery tooling, but cannot
currently post the required issue comment, interaction, or status update from
this shell.

## Verification

- `./scripts/test-paperclip-helpers.sh` passed all 11 smoke tests.
- `./scripts/paperclip-api.sh health` returned:

```json
{
  "status": "ok",
  "deploymentMode": "authenticated",
  "deploymentExposure": "private",
  "bootstrapStatus": "ready",
  "bootstrapInviteActive": false
}
```

- `./scripts/paperclip-runtime-check.sh` confirmed the Paperclip auth blocker
  shown above.

## Conclusion

The Prometheus run is most likely failing in OpenCode model validation, not in
the task body itself. The immediate technical recovery path is to fix the
OpenCode preflight timeout on the Prometheus host or Paperclip runtime, then
rerun the heartbeat. Separately, the CEO Cursor Cloud runtime still needs
`PAPERCLIP_API_KEY` before it can update Paperclip issue state directly.

## Recommended disposition

`blocked`

## Unblock owners and actions

### Blocker 1: Prometheus runtime / Paperclip operator

- Owner: Prometheus runtime owner or Paperclip operator
- Required action:
  1. Upgrade Paperclip to a build that includes the `opencode-local`
     model-validation timeout fix (paperclipai/paperclip PR #2353), or
  2. set `PAPERCLIP_SKIP_MODEL_VALIDATION=true` for the affected runtime if the
     agent configuration is already known-good, and
  3. validate `opencode models` on the Prometheus host before rerunning the
     heartbeat.

### Blocker 2: Osiris Cursor Cloud control-plane auth

- Owner: Paperclip operator
- Required action: inject `PAPERCLIP_API_KEY` into the Osiris Cursor Cloud
  adapter environment so the CEO agent can comment on and update Paperclip
  issues from the shell.

## Smallest next verification after unblock

1. On the Prometheus host, run `opencode models` and confirm it completes
   successfully.
2. Rerun the affected Prometheus heartbeat.
3. In Osiris Cursor Cloud, run `./scripts/paperclip-runtime-check.sh`.
4. If auth is fixed, use:
   - `./scripts/paperclip-api.sh current-issue-playbook`
   - `./scripts/paperclip-api.sh issue-get-current`
   - `./scripts/paperclip-api.sh issue-comment-current-template "Resuming after Prometheus OpenCode preflight fix." true`
   - `./scripts/paperclip-api.sh issue-update-current-template blocked "Prometheus is blocked on OpenCode model-discovery timeout remediation."`

