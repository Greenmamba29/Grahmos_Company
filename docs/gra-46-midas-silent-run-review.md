# GRA-46 - Review silent active run for Midas

This note captures the outcome of the Cursor Cloud heartbeat for GRA-46.

## What this heartbeat confirmed

- The Paperclip deployment is reachable and healthy:
  - `GET /api/health` -> `200`
  - `deploymentMode` -> `authenticated`
  - `deploymentExposure` -> `private`
- This Cursor Cloud shell does not have usable Paperclip board auth:
  - `GET /api/auth/get-session` -> `401`
  - `GET /api/heartbeat-runs/{runId}/issues` -> `401`
- Runtime secrets in this shell include `GH_TOKEN`, but not `PAPERCLIP_API_KEY`.
- The continuation payload identifies the silent run as:
  - agent: **Midas**
  - adapter: **`opencode_local`**
  - started: `2026-06-05T19:37:51.071Z`
  - process started: `2026-06-05T19:37:54.774Z`
  - last output: **none recorded**
  - silence window: **1h**
- The repo metadata still lists **Midas** as a **Hermes Agent (local)** adapter, so
  the repo is stale for this issue and the continuation payload should be treated
  as the source of truth.

## Review conclusion

This heartbeat could not inspect the live Midas run in the Paperclip board or
mutate the Paperclip issue directly because the shell lacks both:

1. a board-authenticated Paperclip session, and
2. an injected `PAPERCLIP_API_KEY`.

Because the live continuation payload confirms Midas is running on
`opencode_local`, the primary review path is now an OpenCode adapter failure
that occurs before normal logging begins.

## Most likely causes to check in order

1. **Retired or unavailable OpenCode model slug**
   - Symptom: the run is launched, but the adapter fails before it emits normal
     progress logs, leaving a suspiciously silent active run.
   - Closest known pattern: GRA-41, where an OpenCode-backed agent failed before
     logging because the configured model slug was no longer available.
   - First check: open the run or adapter config in Paperclip and compare the
     configured model slug against the currently supported OpenCode models.

2. **Broader `opencode_local` adapter startup failure**
   - Symptom: the process starts and remains tracked, but no log tail is ever
     captured because the adapter exits or wedges before the log stream starts.
   - First check: inspect the Paperclip-host logs for the adapter subprocess and
     confirm whether startup failed before the run logger attached.

3. **Stale repository metadata**
   - The repo still says Midas is `Hermes Agent (local)`, but the live run says
     `opencode_local`.
   - After resolving the active run, update the repo metadata or docs so future
     reviews do not start from the wrong adapter assumption.

## Operator unblock

**Unblock owner:** Paperclip operator

**Required action:**
- inject `PAPERCLIP_API_KEY` into the Cursor Cloud adapter environment, or
- inspect the Midas run directly in the Paperclip board UI/logs.

## Recommended next steps after unblock

1. Open run `7c9f971b-199c-439a-a702-a5031907a84b` and inspect the first adapter
   error or configuration attached to the `opencode_local` invocation.
2. If the configured model slug is unavailable:
   - replace it with a currently supported OpenCode model
   - rerun the heartbeat and confirm output begins streaming normally
3. If the model slug is valid:
   - inspect Paperclip-host adapter logs for pre-log startup failure inside
     `opencode_local`
   - repair that startup issue and rerun the heartbeat
4. After recovery, update the Midas adapter documentation in the repo so the
   recorded adapter type matches the live Paperclip configuration.
5. Resume GRA-46 with a structured Paperclip issue update once auth is available.
