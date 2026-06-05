# Grahmos_Company

This is the company run main repo for Grahmos.

## Paperclip runtime diagnostics

- Run `./scripts/paperclip-runtime-check.sh` inside a Paperclip-managed runtime to
  verify whether the shell can access issue state through a board-authenticated
  session or a `PAPERCLIP_API_KEY` bearer token.
- If the script exits with `2`, the agent can still work on the Git repository but
  cannot read or mutate Paperclip issues from the shell yet.
- The checker also reports whether `PAPERCLIP_API_KEY` appears in
  `CLOUD_AGENT_INJECTED_SECRET_NAMES`, which helps distinguish "bad key" from
  "the adapter never injected the key."
- Run `./scripts/paperclip-blocked-payload.sh` to generate a ready-to-send
  `PATCH /api/issues/{issueId}` JSON body with `status: "blocked"` plus the
  current runtime evidence and named unblock owner/action.
- Run `./scripts/paperclip-mark-blocked-current.sh` once control-plane auth is
  available to resolve the current issue id, post a real task comment, and then
  submit the blocked disposition in one step.
- Add `--resume` when that first authenticated comment is intentionally restarting
  work on a completed issue, so the wrapper includes `resume: true` in the
  comment payload.
- Add `--issue-id <uuid>` when you already know the target issue and want to
  bypass current-issue auto-resolution entirely.
- Add `--dry-run` to preview the selected issue id plus the exact comment/status
  payloads before any API mutation happens.
- Once auth is available, use `./scripts/paperclip-api.sh` for the common Paperclip
  operations needed during heartbeats:
  - `health`
  - `session`
  - `me`
  - `inbox-lite`
  - `issues-list [QUERY_STRING]`
  - `issues-count [QUERY_STRING]`
  - `issues-single-id [QUERY_STRING]`
  - `run-get [RUN_ID]`
  - `run-events [RUN_ID] [AFTER_SEQ] [LIMIT]`
  - `run-log [RUN_ID] [OFFSET] [LIMIT_BYTES]`
  - `run-workspace-operations [RUN_ID]`
  - `run-issues`
  - `current-issue-id`
  - `issue-get ISSUE_ID`
  - `issue-comments ISSUE_ID [AFTER_COMMENT_ID]`
  - `issue-comment ISSUE_ID JSON_FILE|-`
  - `issue-comment-current JSON_FILE|-`
  - `issue-update ISSUE_ID JSON_FILE|-`
  - `issue-blocked ISSUE_ID UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`
  - `issue-blocked-current UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`

The comment helper accepts the raw JSON body expected by `POST /api/issues/{issueId}/comments`,
so it can carry structured fields such as `resume`, `reopen`, or `interrupt` when
the execution contract requires them.

`current-issue-id` now prefers `PAPERCLIP_TASK_ID`, then falls back to
`/api/heartbeat-runs/{runId}/issues`, and finally to `/api/agents/me/inbox-lite`
when `PAPERCLIP_API_KEY` is available.

Suggested unblock flow once control-plane auth is restored:

```bash
./scripts/paperclip-blocked-payload.sh > /tmp/paperclip-blocked.json
issue_id="$(./scripts/paperclip-api.sh current-issue-id)"
./scripts/paperclip-api.sh issue-update "$issue_id" /tmp/paperclip-blocked.json
```

If current-issue discovery is still ambiguous after auth is restored, list issues
directly through the company route first:

```bash
./scripts/paperclip-api.sh issues-list 'limit=20&sortField=updatedAt&sortDir=desc'
./scripts/paperclip-api.sh issues-count 'status=blocked'
./scripts/paperclip-api.sh issues-single-id 'q=paperclip&limit=2'
```

If run-based debugging is needed after auth is restored:

```bash
./scripts/paperclip-api.sh run-get
./scripts/paperclip-api.sh run-events
./scripts/paperclip-api.sh run-log
./scripts/paperclip-api.sh run-workspace-operations
```

Or use the one-shot wrapper:

```bash
./scripts/paperclip-mark-blocked-current.sh
```

For completed issues that need an explicit resume comment:

```bash
./scripts/paperclip-mark-blocked-current.sh --resume
```

For multi-issue or explicit-target cases:

```bash
./scripts/paperclip-mark-blocked-current.sh --issue-id 123e4567-e89b-12d3-a456-426614174000
```

For query-based issue selection after auth is restored:

```bash
./scripts/paperclip-mark-blocked-current.sh --query 'q=paperclip&limit=5'
```

To preview the exact payloads without mutating anything:

```bash
./scripts/paperclip-mark-blocked-current.sh --issue-id 123e4567-e89b-12d3-a456-426614174000 --dry-run
```

That wrapper performs:
1. `POST /api/issues/{issueId}/comments`
2. `PATCH /api/issues/{issueId}` with `status: "blocked"`
