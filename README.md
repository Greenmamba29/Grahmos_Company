# Grahmos_Company

This is the Company run main repo for Grahmos.

## Paperclip runtime diagnostics

- Run `./scripts/paperclip-runtime-check.sh` inside a Paperclip-managed runtime to
  verify whether the shell can access issue state through a board-authenticated
  session or a `PAPERCLIP_API_KEY` bearer token.
- If the script exits with `2`, the agent can still work on the Git repository but
  cannot read or mutate Paperclip issues from the shell yet.
- Once auth is available, use `./scripts/paperclip-api.sh` for the common Paperclip
  operations needed during heartbeats:
  - `health`
  - `session`
  - `current-run-issues`
  - `me`
  - `inbox-lite`
  - `current-issue-id`
  - `issue-get ISSUE_ID`
  - `issue-get-current`
  - `issue-comments ISSUE_ID [AFTER_COMMENT_ID]`
  - `issue-comments-current [AFTER_COMMENT_ID]`
  - `issue-comment ISSUE_ID JSON_FILE|-`
  - `issue-comment-current JSON_FILE|-`
  - `issue-interaction ISSUE_ID JSON_FILE|-`
  - `issue-interaction-current JSON_FILE|-`
  - `issue-update ISSUE_ID JSON_FILE|-`
  - `issue-update-current JSON_FILE|-`
  - `issue-blocked ISSUE_ID UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`
  - `issue-blocked-current UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`

The comment helper accepts the raw JSON body expected by `POST /api/issues/{issueId}/comments`,
so it can carry structured fields such as `resume`, `reopen`, or `interrupt` when
the execution contract requires them.
The interaction helper accepts the raw JSON body expected by
`POST /api/issues/{issueId}/interactions`, so the shell can create
`suggest_tasks`, `ask_user_questions`, or `request_confirmation` interactions once
Paperclip auth is available.
When `PAPERCLIP_TASK_ID` is missing, `current-issue-id` now prefers the
`/api/heartbeat-runs/{runId}/issues` lookup before falling back to inbox-lite, so
the helper aligns with the runtime diagnostic and can use the run-bound issue list
whenever a board-authenticated session is available.
The same resolution order now powers `issue-get-current`,
`issue-comments-current`, and `issue-update-current`, so current-task reads and
final disposition updates do not need an explicit issue ID once auth is available.

## Helper regression test

- Run `./scripts/test-paperclip-tools.sh` for the full Paperclip helper verification
  suite. It checks shell syntax and then runs both mock-server smoke tests.
- See `./scripts/paperclip-payload-examples.md` for copy/paste payloads covering
  resume comments, current-issue updates, blocked dispositions, and the supported
  interaction kinds.
- Run `./scripts/test-paperclip-api.sh` to exercise the helper against a local
  mock Paperclip API. The smoke test covers current-issue resolution, run-bound
  issue lookup, current-task read/update helpers, interaction/comment posting,
  and blocked disposition payload generation.
- Run `./scripts/test-paperclip-runtime-check.sh` to exercise the runtime
  diagnostic against a local mock Paperclip API. The smoke test covers missing
  env handling, board-session success, blocked-no-auth behavior, bearer-token
  success, and rejected bearer auth.
