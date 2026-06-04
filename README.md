# Grahmos_Company

This is the Company run main repo for Grahmos.

## Paperclip runtime diagnostics

- Run `./scripts/paperclip-runtime-check.sh` inside a Paperclip-managed runtime to
  verify whether the shell can access issue state through a board-authenticated
  session or a `PAPERCLIP_API_KEY` bearer token.
- If the script exits with `2`, the agent can still work on the Git repository but
  cannot read or mutate Paperclip issues from the shell yet.
- The runtime check also inspects `CLOUD_AGENT_INJECTED_SECRET_NAMES` so it can say
  whether `PAPERCLIP_API_KEY` was ever injected into the cloud shell at all.
- `GH_TOKEN` may be present for repository operations, but it does not authenticate
  Paperclip issue/comment/interaction endpoints.
- An auxiliary agent-home env var may also be present in runtime metadata; if it is
  not a readable directory in the shell, it is not a reliable fallback source for
  current-task context.
- Once auth is available, use `./scripts/paperclip-api.sh` for the common Paperclip
  operations needed during heartbeats:
  - `health`
  - `session`
  - `me`
  - `inbox-lite`
  - `adapter-env-template PAPERCLIP_SECRET_ID [CURSOR_SECRET_ID]`
  - `current-issue-id`
  - `issue-get ISSUE_ID`
  - `issue-comments ISSUE_ID [AFTER_COMMENT_ID]`
  - `issue-comment ISSUE_ID JSON_FILE|-`
  - `issue-comment-current JSON_FILE|-`
  - `issue-interaction ISSUE_ID JSON_FILE|-`
  - `issue-interaction-current JSON_FILE|-`
  - `issue-update ISSUE_ID JSON_FILE|-`
  - `issue-blocked ISSUE_ID UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`
  - `issue-blocked-current UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`

The comment helper accepts the raw JSON body expected by `POST /api/issues/{issueId}/comments`,
so it can carry structured fields such as `resume`, `reopen`, or `interrupt` when
the execution contract requires them.
The interaction helper accepts the raw JSON body expected by
`POST /api/issues/{issueId}/interactions`, so the agent can create
`ask_user_questions`, `suggest_tasks`, or `request_confirmation` records once auth
is available.
When the runtime check shows that `PAPERCLIP_API_KEY` was never injected, run
`./scripts/paperclip-api.sh adapter-env-template YOUR_PAPERCLIP_SECRET_ID [YOUR_CURSOR_SECRET_ID]`
to print the adapter JSON needed for the fix.
