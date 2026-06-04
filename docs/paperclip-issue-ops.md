# Paperclip Issue Ops Runbook

This repo now includes several helpers for authenticated Paperclip issue work:

```bash
./scripts/paperclip-api
./scripts/paperclip-issue-update
./scripts/paperclip-issue-interaction
./scripts/paperclip-blocked-update
```

Use it when a Cursor cloud agent needs to:

- list assigned issues
- post heartbeat comments
- update an issue disposition
- create issue-thread interactions after preparing a proposal

## Why this exists

Cursor cloud runs expose useful runtime IDs such as:

- `PAPERCLIP_API_URL`
- `PAPERCLIP_COMPANY_ID`
- `PAPERCLIP_AGENT_ID`
- `PAPERCLIP_RUN_ID`

Those IDs are enough to build the correct API paths, but they are not always
enough to authenticate API requests. In practice, a cloud shell can see the
runtime metadata while unauthenticated requests to `/api/...` still return 401.

These helpers standardize the call pattern so an agent can move quickly once a
board-authenticated header or session cookie is available.

## Auth requirements

Set one of the following before calling the helper:

```bash
export PAPERCLIP_AUTH_HEADER="Bearer <token>"
```

or

```bash
export PAPERCLIP_COOKIE_HEADER="paperclip_session=<value>"
```

If neither is set, the helper exits with a clear error message.

## Common operations

### 1. List issues assigned to the current agent

```bash
./scripts/paperclip-api GET \
  "/companies/$PAPERCLIP_COMPANY_ID/issues?assigneeAgentId=$PAPERCLIP_AGENT_ID&limit=20&sortField=updatedAt&sortDir=desc"
```

Use this first when the issue ID is not already known.

### 2. Post the required heartbeat comment

```bash
ISSUE_ID="<issue-uuid>"

./scripts/paperclip-issue-update \
  --issue-id "$ISSUE_ID" \
  --comment "Heartbeat: investigated the task, started implementation, and will return with verification and final disposition."
```

Paperclip instructions require every heartbeat to leave a durable task comment.
Make this the first write once the issue ID is known.

### 3. Update the issue disposition

```bash
./scripts/paperclip-issue-update \
  --issue-id "$ISSUE_ID" \
  --comment "Completed implementation and verified the helper behavior locally." \
  --status done
```

Use `done`, `blocked`, or `in_review` only when the real state matches the
execution contract.

### 3a. Auto-resolve the current assigned issue

If the current agent has exactly one active assigned issue, the helper can
resolve it automatically from `PAPERCLIP_COMPANY_ID` and `PAPERCLIP_AGENT_ID`:

```bash
./scripts/paperclip-issue-update \
  --comment "Heartbeat: resumed work and am applying the next change now." \
  --status in_progress
```

If multiple active issues are assigned, the helper exits with a short list and
asks for an explicit `--issue-id`.

If you are intentionally restarting follow-up work on a completed issue, pass
`--resume` so the helper includes structured `resume: true` on the comment and
status update payloads.

### 4. Create a follow-up interaction instead of freeform markdown questions

```bash
./scripts/paperclip-issue-interaction \
  --issue-id "$ISSUE_ID" \
  --kind ask_user_questions \
  --title "Need operator input" \
  --summary "Two valid next steps need board selection." \
  --payload-file interaction.json
```

The JSON payload should match the interaction kind you need:

- `suggest_tasks`
- `ask_user_questions`
- `request_confirmation`

For plan approval, update the plan document first, then create
`request_confirmation` against the latest plan revision.

You can print schema-correct starter payloads for each interaction kind:

```bash
./scripts/paperclip-issue-interaction --print-example suggest_tasks
./scripts/paperclip-issue-interaction --print-example ask_user_questions
./scripts/paperclip-issue-interaction --print-example request_confirmation
```

Key schema details recovered from the Paperclip frontend bundle:

- `suggest_tasks`
  - `payload.version = 1`
  - `payload.tasks` is required, 1-50 items
  - each task requires a unique `clientKey` and a `title`
  - optional task fields include `parentClientKey`, `parentId`, `description`,
    `priority`, `workMode`, `assigneeAgentId`, `assigneeUserId`, `projectId`,
    `goalId`, `billingCode`, `labels`, and `hiddenInPreview`
- `ask_user_questions`
  - `payload.version = 1`
  - `payload.questions` is required, 1-10 items
  - each question requires unique `id`, `prompt`, `selectionMode`, and `options`
  - options require unique `id` and `label`
- `request_confirmation`
  - `payload.version = 1`
  - `payload.prompt` is required
  - optional fields include `acceptLabel`, `rejectLabel`,
    `rejectRequiresReason`, `rejectReasonLabel`, `allowDeclineReason`,
    `declineReasonPlaceholder`, `detailsMarkdown`, `supersedeOnUserComment`,
    and `target`
  - default `continuationPolicy` is `none` for confirmations, while
    `suggest_tasks` and `ask_user_questions` default to `wake_assignee`

## Recommended heartbeat flow

1. Resolve the active issue ID.
2. Post a heartbeat comment immediately.
3. Do the smallest real unit of work that moves the issue forward.
4. Verify only what the scope requires.
5. Post a closing comment with evidence.
6. Patch the issue to its final disposition.

## Troubleshooting

### 401 Unauthorized

The runtime has IDs but not board auth. Export a valid `PAPERCLIP_AUTH_HEADER`
or `PAPERCLIP_COOKIE_HEADER`, then retry the helper command.

### I can identify the run, but not the task

Use `./scripts/paperclip-issue-update` without `--issue-id` after auth is
available. It will query issues assigned to the current agent and auto-select
the issue only when the assignment is unambiguous.

### 401 Board authentication required

This usually means the Paperclip board requires an authenticated browser session
or session cookie, even though the repo workspace and heartbeat env vars are
already present.

### I need to mark the issue blocked cleanly

Use the blocked helper so the issue comment always names the unblock owner and
required action before patching the issue to `blocked`:

```bash
./scripts/paperclip-blocked-update \
  --reason "Paperclip board auth is unavailable from the cloud shell." \
  --owner "Paperclip platform/operator" \
  --action "Inject a valid PAPERCLIP_AUTH_HEADER or PAPERCLIP_COOKIE_HEADER into the runtime." \
  --evidence "Direct /api requests returned 401 Unauthorized and Board authentication required."
```

This helper posts a durable comment first, then patches the issue status to
`blocked`.

### Need to inspect a payload before scripting it

Use the Paperclip web UI for the first operation, then mirror the confirmed
request shape from browser devtools or from the frontend bundle when necessary.
