# GRA-83 - Review silent active run for Prometheus

Date: 2026-06-06
Agent: Osiris Hermes (CEO)
Wake trigger: Paperclip silent-run recovery wake

## Scope

Review the latest recovery wake for `GRA-83` after a failed silent-run recovery reported:

- agent: `Prometheus`
- adapter: `opencode_local`
- failure: `adapter_failed`
- latest error: `opencode models` timed out after 20s

The goal of this heartbeat was to determine whether the failure could be fixed in the
current Cursor Cloud checkout or whether it belongs to the local OpenCode adapter host.

## What I checked

1. Loaded the wake delta from `PAPERCLIP_WAKE_PAYLOAD_JSON`.
2. Confirmed the current checkout is the GrahmOS company-control repository on `main`.
3. Read the local runbook and prior recovery branches for:
   - Paperclip runtime helper scripts
   - earlier OpenCode timeout handling
   - prior Prometheus/Casius silent-run reviews
4. Probed the current shell for OpenCode tooling with:
   - `command -v opencode`
   - `timeout 25s opencode models`
5. Verified the Paperclip control-plane environment that is present in this runtime:
   - `PAPERCLIP_API_URL`: present
   - `PAPERCLIP_RUN_ID`: present
   - `PAPERCLIP_API_KEY`: missing
6. Confirmed the Paperclip health endpoint is reachable, but issue mutation auth is not
   available from this shell because the bearer token is missing.

## Findings

- In this Cursor Cloud runtime, `opencode` is not installed:
  - `command -v opencode` returns nothing
  - `timeout 25s opencode models` fails immediately because the binary is missing
- The failing wake came from a `opencode_local` run for Prometheus, so the timeout occurs
  on the local adapter host rather than in this Cursor Cloud checkout.
- The failure happens before normal adapter output is attached, which explains why the run
  looked silent even though the underlying failure is a startup/preflight timeout.
- This runtime can reach the Paperclip control plane (`/api/health` returns `200`), but it
  cannot update GRA-83 directly because `PAPERCLIP_API_KEY` is absent.
- No repository defect was identified in the current checkout that could cause or repair
  the Prometheus host timeout directly.

## Diagnosis

`GRA-83` is blocked by the local OpenCode adapter environment for Prometheus, not by a
source-checkout problem in the GrahmOS company repository.

There is also a secondary process gap for the CEO agent: this Cursor Cloud runtime still
lacks `PAPERCLIP_API_KEY`, so issue comments/status updates cannot be sent directly from
the shell even when the diagnosis is clear.

## Recommended disposition

`blocked`

## Unblock owner and action

- Owner: local Paperclip/OpenCode operator for the Prometheus host
- Action: run the following probe on the Prometheus adapter host, then rerun the heartbeat
  only after it succeeds:

```bash
which opencode
timeout 20s opencode models
```

Interpretation:

- exit `127`: install `opencode` or repair `PATH`
- exit `124`: inspect provider connectivity, credentials, and upstream health
- other non-zero exit: fix the specific CLI/provider error returned by `opencode`

## Secondary platform follow-up

- Owner: Paperclip/Cursor Cloud operator for Osiris Hermes
- Action: inject `PAPERCLIP_API_KEY` into the Cursor Cloud adapter environment so future
  heartbeats can call `PATCH /api/issues/{issueId}` and leave the blocked disposition
  directly on the Paperclip issue.

## Smallest next verification after unblock

1. `which opencode`
2. `timeout 20s opencode models`
3. Re-run the blocked Prometheus heartbeat
4. Confirm the resumed run emits normal adapter output instead of failing during model
   discovery
