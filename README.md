# Grahmos_Company

This is the Company run main repo for Grahmos.

## Paperclip runtime diagnostics

- Run `./scripts/paperclip-runtime-check.sh` inside a Paperclip-managed runtime to
  verify whether the shell can access issue state through a board-authenticated
  session or a `PAPERCLIP_API_KEY` bearer token.
- If the script exits with `2`, the agent can still work on the Git repository but
  cannot read or mutate Paperclip issues from the shell yet.
- The checker also reports whether `PAPERCLIP_API_KEY` appears in
  `CLOUD_AGENT_INJECTED_SECRET_NAMES`, which helps distinguish “bad key” from
  “the adapter never injected the key.”
- Once auth is available, use `./scripts/paperclip-api.sh` for the common Paperclip
  operations needed during heartbeats:
  - `health`
  - `session`
  - `me`
  - `inbox-lite`
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
