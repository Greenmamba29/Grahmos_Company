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
- The repo metadata still lists **Midas** as a **Hermes Agent (local)** adapter.

## Review conclusion

This heartbeat could not inspect the live Midas run or mutate the Paperclip issue
directly because the shell lacks both:

1. a board-authenticated Paperclip session, and
2. an injected `PAPERCLIP_API_KEY`.

Because the repo metadata lists Midas as `Hermes Agent (local)`, the first
review path for a "silent active run" should be the local Hermes bootstrap,
not the Cursor Cloud adapter.

## Most likely causes to check in order

1. **Hermes local adapter bootstrap failure**
   - Symptom: the run appears active or stuck but emits little to no progress.
   - First check: whether the Paperclip host can launch `hermes` and whether the
     Midas working directory still exists.
   - Relevant known error: `Failed to start command hermes in .`

2. **Adapter drift from repo metadata**
   - If the live Midas agent was changed from `Hermes Agent (local)` to an
     OpenCode-backed adapter in Paperclip, a retired model slug can also look
     like a silent run because the adapter fails before normal logs begin.
   - In that case, review the actual run error and replace the retired model
     slug with a currently supported OpenCode model.

## Operator unblock

**Unblock owner:** Paperclip operator

**Required action:**
- inject `PAPERCLIP_API_KEY` into the Cursor Cloud adapter environment, or
- inspect the Midas run directly in the Paperclip board UI/logs.

## Recommended next steps after unblock

1. Open the Midas run and inspect the first error emitted by the adapter.
2. If Midas is still `Hermes Agent (local)`:
   - verify `hermes` is installed on the Paperclip host
   - verify the configured working directory exists and is readable
   - rerun after fixing the local runtime
3. If Midas is actually using OpenCode:
   - replace any retired model slug with a currently available one
   - rerun the heartbeat
4. Resume GRA-46 with a structured Paperclip issue update once auth is available.
