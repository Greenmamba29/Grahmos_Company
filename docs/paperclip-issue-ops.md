# Paperclip Issue Ops Runbook

This repo now includes a small shell helper for authenticated Paperclip API calls:

```bash
./scripts/paperclip-api
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

This helper standardizes the call pattern so an agent can move quickly once a
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

./scripts/paperclip-api POST \
  "/issues/$ISSUE_ID/comments" \
  '{"body":"Heartbeat: investigated the task, started implementation, and will return with verification and final disposition.","interrupt":false}'
```

Paperclip instructions require every heartbeat to leave a durable task comment.
Make this the first write once the issue ID is known.

### 3. Update the issue disposition

```bash
./scripts/paperclip-api PATCH \
  "/issues/$ISSUE_ID" \
  '{"status":"done"}'
```

Use `done`, `blocked`, or `in_review` only when the real state matches the
execution contract.

### 4. Create a follow-up interaction instead of freeform markdown questions

```bash
./scripts/paperclip-api POST \
  "/issues/$ISSUE_ID/interactions" \
  @interaction.json
```

The JSON payload should match the interaction kind you need:

- `suggest_tasks`
- `ask_user_questions`
- `request_confirmation`

For plan approval, update the plan document first, then create
`request_confirmation` against the latest plan revision.

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

### 401 Board authentication required

This usually means the Paperclip board requires an authenticated browser session
or session cookie, even though the repo workspace and heartbeat env vars are
already present.

### Need to inspect a payload before scripting it

Use the Paperclip web UI for the first operation, then mirror the confirmed
request shape from browser devtools or from the frontend bundle when necessary.
