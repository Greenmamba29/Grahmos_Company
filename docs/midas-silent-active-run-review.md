# Midas silent active run review

This note captures the current durable review path for Paperclip issues that ask
Osiris Hermes to review a silent active run for Midas.

## What this heartbeat verified

- The repo itself does not contain live Paperclip issue or run state; the board
  or continuation payload must be treated as the runtime source of truth.
- This Cursor Cloud shell can reach the Paperclip deployment and static assets.
- Protected Paperclip board endpoints remain unavailable from this shell without
  explicit board auth:
  - `GET /api/auth/get-session` -> `401 Board authentication required`
  - `GET /api/companies/{companyId}/issues` -> `401 Unauthorized`
- Runtime secrets in this shell include `GH_TOKEN`, but not
  `PAPERCLIP_API_KEY`.
- The last verified live Midas signal captured in repo history pointed to an
  `opencode_local` run that started but never emitted output. That is the best
  live adapter evidence currently available from this environment.

## Review conclusion

This heartbeat can document the review path and unblock owner, but it cannot
directly inspect the live Midas run or mutate the Paperclip issue from this
shell until Paperclip board auth is provided.

## Likely causes to check in order once unblocked

1. **Retired or unavailable OpenCode model slug**
   - Symptom: the run starts but never emits normal progress logs.
   - First check: compare the configured OpenCode model slug against the
     currently supported models in the live adapter config.

2. **`opencode_local` adapter startup failure before log attachment**
   - Symptom: Paperclip tracks a live run, but no output is ever captured.
   - First check: inspect Paperclip host logs for adapter startup failure before
     the run logger attaches.

3. **Wrong adapter assumption in repo memory**
   - Symptom: investigators follow Hermes-local bootstrap steps even though the
     live run is no longer Hermes-backed.
   - First check: confirm the adapter type from the live run payload or board
     detail before diagnosing startup.

4. **Hermes-local bootstrap failure**
   - Use this path only if the live run explicitly shows `Hermes Agent (local)`.
   - First check: verify the Paperclip host has the `hermes` binary available
     and the configured working directory exists.

## Operator unblock

**Unblock owner:** Paperclip operator

**Required action:**
- inject `PAPERCLIP_API_KEY` into the Cursor Cloud adapter environment, or
- inspect the live Midas run directly in a board-authenticated Paperclip
  session and update the issue from there.

## Recommended next steps after unblock

1. Open the active Midas run from the Paperclip issue detail and inspect the
   first adapter error or configuration attached to the invocation.
2. If the run is `opencode_local`, validate the configured model slug before
   spending time on broader host debugging.
3. If the model slug is valid, inspect host-side adapter startup logs for a
   failure before the normal log stream begins.
4. If the run is actually Hermes-backed, switch to the Hermes bootstrap checks
   instead of the OpenCode path.
5. Resume the Paperclip issue with a structured update once authenticated issue
   mutation is available.
