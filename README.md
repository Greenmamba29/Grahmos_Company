# Grahmos_Company

This is the main company repo for GrahmOS.

## Operator Notes

- Use `configs/osiris-cursor-cloud-adapter.example.json` as the source-of-truth
  template for Osiris Hermes Cursor Cloud secret injection.
- The Cursor Cloud adapter must include both `CURSOR_API_KEY` and
  `PAPERCLIP_API_KEY` for Paperclip issue and run operations.

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
  - `current-issue-playbook`
  - `comment-template BODY [RESUME_TRUE_OR_FALSE]`
  - `update-template STATUS COMMENT [RESUME_TRUE_OR_FALSE]`
  - `blocked-template UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`
  - `interaction-template KIND TITLE [JSON_FILE|-]`
  - `ask-user-questions-template TITLE [JSON_FILE|-]`
  - `suggest-tasks-template TITLE [JSON_FILE|-]`
  - `request-confirmation-template TITLE [JSON_FILE|-]`
  - `current-issue-id`
  - `issue-get ISSUE_ID`
  - `issue-get-current`
  - `issue-comments ISSUE_ID [AFTER_COMMENT_ID]`
  - `issue-comments-current [AFTER_COMMENT_ID]`
  - `issue-comment ISSUE_ID JSON_FILE|-`
  - `issue-comment-current JSON_FILE|-`
  - `issue-comment-current-template BODY [RESUME_TRUE_OR_FALSE]`
  - `issue-interaction ISSUE_ID JSON_FILE|-`
  - `issue-interaction-current JSON_FILE|-`
  - `issue-interaction-current-template KIND TITLE [JSON_FILE|-]`
  - `issue-update ISSUE_ID JSON_FILE|-`
  - `issue-update-current JSON_FILE|-`
  - `issue-update-current-template STATUS COMMENT [RESUME_TRUE_OR_FALSE]`
  - `issue-blocked ISSUE_ID UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`
  - `issue-blocked-current UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`
  - `issue-blocked-current-template UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`
- When the runtime is still blocked, run
  `./scripts/paperclip-operator-unblock.sh [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]`
  to print a complete operator handoff: the blocked-status payload, the adapter env
  JSON needed to inject `PAPERCLIP_API_KEY`, and the replay commands for the next
  heartbeat.

The comment helper accepts the raw JSON body expected by `POST /api/issues/{issueId}/comments`,
so it can carry structured fields such as `resume`, `reopen`, or `interrupt` when
the execution contract requires them. The interaction helper accepts the raw JSON
body expected by `POST /api/issues/{issueId}/interactions`, so the agent can create
`ask_user_questions`, `suggest_tasks`, or `request_confirmation` records once auth
is available. Run `./scripts/test-paperclip-helpers.sh` to smoke-test the helper
CLI surface before relying on it in a live heartbeat.
