# GRA-40 - Review silent active run for Lyra

## Summary

This heartbeat reviewed the Paperclip wake payload for Lyra's silent run
`eda09d21-2ca1-4e11-abcc-224e27a4ebb5`, which had no recorded output and had
been silent for roughly one hour when flagged. The Cursor Cloud runtime can
reach the Paperclip host, but it does not have the board-authenticated session
required to inspect or intervene on the live run through the Paperclip API.

## Wake Context

- Issue: `GRA-40`
- Issue title: `Review silent active run for Lyra`
- Agent under review: `Lyra`
- Adapter: `opencode_local`
- Suspicious run: `eda09d21-2ca1-4e11-abcc-224e27a4ebb5`
- Process metadata from the wake payload: pid `31033`, process group `31033`,
  in-memory handle `yes`
- Last recorded output: none
- Recent events in wake payload:
  - `run started`
  - `adapter invocation`

## What Was Checked

1. Confirmed the Paperclip runtime context is present in the cloud shell via
   the injected `PAPERCLIP_*` environment variables.
2. Confirmed the Paperclip web app is reachable from Cursor Cloud.
3. Extracted the frontend API paths from the Paperclip app bundle to verify the
   relevant run-review endpoints for issue active-run, live-runs, heartbeat-run
   detail, log, events, cancel, and watchdog decisions.
4. Probed the live endpoints for this issue and run from the shell.

## Endpoint Results

These requests were made from the authenticated GitHub runtime only, without a
Paperclip board session cookie:

| Endpoint | Result |
| --- | --- |
| `GET /api/auth/get-session` | `401 {"error":"Board authentication required"}` |
| `GET /api/issues/GRA-40/active-run` | `401 {"error":"Unauthorized"}` |
| `GET /api/issues/GRA-40/live-runs` | `401 {"error":"Unauthorized"}` |
| `GET /api/heartbeat-runs/eda09d21-2ca1-4e11-abcc-224e27a4ebb5` | `401 {"error":"Unauthorized"}` |
| `GET /api/heartbeat-runs/eda09d21-2ca1-4e11-abcc-224e27a4ebb5/events` | `401 {"error":"Unauthorized"}` |
| `GET /api/heartbeat-runs/eda09d21-2ca1-4e11-abcc-224e27a4ebb5/log` | `401 {"error":"Unauthorized"}` |
| `POST /api/heartbeat-runs/eda09d21-2ca1-4e11-abcc-224e27a4ebb5/cancel` | `403 {"error":"Board access required"}` |
| `POST /api/heartbeat-runs/eda09d21-2ca1-4e11-abcc-224e27a4ebb5/watchdog-decisions` | `401 {"error":"Unauthorized"}` |

## Conclusion

The blocker is not network reachability and not an unknown endpoint shape. The
Cursor Cloud runtime lacks the Paperclip board authentication needed to:

- confirm whether the Lyra run is still active,
- inspect the run log or events,
- cancel the run,
- record a watchdog decision, or
- leave a direct Paperclip issue comment/status update.

The injected `PAPERCLIP_*` variables provide runtime context only; they do not
authenticate issue or heartbeat-run API calls.

## Recommended Unblock

- **Unblock owner:** Paperclip platform operator / board admin
- **Required action:** Review the run from a board-authenticated Paperclip
  session or inject a dedicated Paperclip service credential into the Cursor
  Cloud runtime for watchdog issue handling.
- **Minimum follow-up checks once authenticated:**
  1. Read `GET /api/issues/GRA-40/active-run` and `GET /api/issues/GRA-40/live-runs`
     to confirm the current live-run state.
  2. Inspect `GET /api/heartbeat-runs/eda09d21-2ca1-4e11-abcc-224e27a4ebb5`,
     `/events`, and `/log`.
  3. If the run is still stalled, call
     `POST /api/heartbeat-runs/eda09d21-2ca1-4e11-abcc-224e27a4ebb5/cancel`.
  4. Record the final watchdog disposition and issue status from the same
     authenticated context.

## Disposition Recommendation

`blocked` - blocked on Paperclip board authentication for run inspection and
control. The first-class unblock is owned by the Paperclip operator/admin, who
must supply a board-authenticated session or service credential.
