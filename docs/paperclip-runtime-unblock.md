# Paperclip Runtime Unblock Handoff

This document captures the exact task-update payloads and commands needed to close
the current Paperclip control-plane blocker from a Cursor Cloud shell once
`PAPERCLIP_API_KEY` is available.

## Current runtime state

Verified in this workspace on 2026-06-05 with:

```sh
./scripts/paperclip-runtime-check.sh
```

Observed result:

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
  "bearer_me_status": null,
  "bearer_inbox_status": null
}
```

Interpretation:

- The Paperclip deployment is reachable.
- The shell does not have a board-authenticated session cookie.
- The shell does not have `PAPERCLIP_API_KEY`.
- Issue reads, comments, interactions, and disposition updates are blocked until one
  of those auth paths exists.

## GRA-39 / Echo-specific blocker

This heartbeat was woken for `GRA-39 - Review silent active run for Echo`. The wake
payload already included the concrete failure that ended the previous recovery run:

```text
Configured OpenCode model is unavailable: openai/gpt-5.1-codex-mini
Available models: opencode/big-pickle, opencode/deepseek-v4-flash-free,
opencode/mimo-v2.5-free, opencode/minimax-m3-free,
opencode/nemotron-3-ultra-free
```

Interpretation:

- The source issue is blocked by stale Echo adapter configuration in Paperclip, not
  by repository code.
- This Cursor Cloud shell has a second blocker: it cannot record that disposition on
  the issue thread until a board session or `PAPERCLIP_API_KEY` exists.

## Ready-to-send Echo blocked disposition payload

Once Paperclip auth is restored, send the checked-in GRA-39 blocker payload:

```sh
./scripts/paperclip-send-current.sh gra-39-echo-blocked
```

Equivalent direct command:

```sh
./scripts/paperclip-api.sh issue-update-current paperclip/payloads/gra-39-echo-model-blocked.json
```

The payload names the required unblock action explicitly:

- Unblock owner: Echo adapter operator / Osiris Hermes
- Required action: update Echo's `opencode_local` model to one of the currently
  available OpenCode models and rerun the recovery heartbeat

## Unblock owner and required action

- Unblock owner: Paperclip operator / Osiris Hermes
- Required action: inject `PAPERCLIP_API_KEY` into the Cursor Cloud adapter
  environment, then rerun the heartbeat

## Ready-to-send blocked disposition payload

If the rerun still wakes on the same blocked task and the issue must be marked
blocked immediately, use this payload:

```json
{
  "status": "blocked",
  "comment": "Blocked.\n\nUnblock owner: Paperclip operator / Osiris Hermes\nRequired action: Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter environment and rerun the heartbeat.\n\nDetails: Verified in Cursor Cloud with ./scripts/paperclip-runtime-check.sh. The runtime can reach the private Paperclip deployment, but /api/auth/get-session returns 401 and /api/heartbeat-runs/{runId}/issues returns 401 because the shell has neither a board-authenticated session nor PAPERCLIP_API_KEY."
}
```

Send it with:

```sh
./scripts/paperclip-send-current.sh blocked-current
```

Equivalent direct command:

```sh
./scripts/paperclip-api.sh issue-update-current paperclip/payloads/blocked-current.json
```

## Ready-to-send resume comment payload

If auth has been fixed and the task should resume with a structured wake signal:

```json
{
  "body": "Resuming after Paperclip control-plane auth was restored. Repo-side helpers, diagnostics, and task-update workflows are implemented on branch cursor/echo-run-recovery-9c83 and verified locally.",
  "resume": true
}
```

Send it with:

```sh
./scripts/paperclip-send-current.sh resume-comment
```

Equivalent direct command:

```sh
./scripts/paperclip-api.sh issue-comment-current paperclip/payloads/resume-comment.json
```

## Optional follow-up interaction payload

If the task needs structured operator input instead of an immediate unblock:

```json
{
  "kind": "ask_user_questions",
  "title": "Paperclip auth path unavailable in Cursor Cloud",
  "summary": "The shell can modify the Git repo but cannot update the assigned Paperclip issue without control-plane auth.",
  "continuationPolicy": "wake_assignee",
  "payload": {
    "title": "Which auth path should Osiris Hermes use for Paperclip issue updates?",
    "questions": [
      {
        "id": "paperclip-auth-path",
        "label": "Choose the unblock path",
        "helpText": "Inject PAPERCLIP_API_KEY into the Cursor Cloud adapter env, or provide another supported control-plane auth path."
      }
    ]
  }
}
```

Send it with:

```sh
./scripts/paperclip-send-current.sh auth-question
```

Equivalent direct command:

```sh
./scripts/paperclip-api.sh issue-interaction-current paperclip/payloads/auth-question.json
```
