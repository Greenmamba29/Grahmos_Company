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
  - `current-agent-id`
  - `current-company-id`
  - `secrets-list [COMPANY_ID]`
  - `secret-find QUERY [COMPANY_ID]`
  - `secret-id QUERY [COMPANY_ID]`
  - `secret-id-from-json JSON_FILE|- QUERY`
  - `adapter-env-template PAPERCLIP_SECRET_ID [CURSOR_SECRET_ID]`
  - `agent-get AGENT_ID [COMPANY_ID]`
  - `agent-get-current`
  - `agent-config AGENT_ID [COMPANY_ID]`
  - `agent-config-current`
  - `agent-update AGENT_ID JSON_FILE|- [COMPANY_ID]`
  - `agent-update-current JSON_FILE|-`
  - `agent-env-patch-template AGENT_JSON_FILE|- ENV_NAME SECRET_ID [VERSION]`
  - `agent-paperclip-key-patch-template AGENT_JSON_FILE|- PAPERCLIP_SECRET_ID [VERSION]`
  - `agent-inject-secret-ref AGENT_ID ENV_NAME SECRET_ID [VERSION] [COMPANY_ID]`
  - `agent-inject-secret-ref-current ENV_NAME SECRET_ID [VERSION]`
  - `agent-inject-paperclip-key AGENT_ID PAPERCLIP_SECRET_ID [VERSION] [COMPANY_ID]`
  - `agent-inject-paperclip-key-current PAPERCLIP_SECRET_ID [VERSION]`
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
the execution contract requires them.
The interaction helper accepts the raw JSON body expected by
`POST /api/issues/{issueId}/interactions`, so the agent can create
`ask_user_questions`, `suggest_tasks`, or `request_confirmation` records once auth
is available.
When the runtime check shows that `PAPERCLIP_API_KEY` was never injected, run
`./scripts/paperclip-api.sh adapter-env-template YOUR_PAPERCLIP_SECRET_ID [YOUR_CURSOR_SECRET_ID]`
to print the adapter JSON needed for the fix.
If the shell already has Paperclip bearer auth and just needs to update the current
agent configuration, run
`./scripts/paperclip-api.sh agent-inject-paperclip-key-current YOUR_PAPERCLIP_SECRET_ID`
to merge `PAPERCLIP_API_KEY` into the current Cursor Cloud adapter env and send the
`PATCH /api/agents/{id}` request directly.
If you do not know the secret UUID yet, resolve it first with
`./scripts/paperclip-api.sh secret-find QUERY` / `secret-id QUERY`, or use the
one-step current-agent helper
`./scripts/paperclip-api.sh agent-inject-paperclip-key-current-by-query QUERY`.
After auth is fixed, run `./scripts/paperclip-api.sh current-issue-playbook` for the
recommended inspection, comment, interaction, blocked, and done commands.
When you need a structured comment or status payload for the execution contract, run
`comment-template`, `update-template`, or `blocked-template` and pipe the result into
the matching `*-current` helper once auth is available.
When you need an interaction payload, run `interaction-template` with a kind/title
plus extra JSON for fields like `questions`, `continuationPolicy`,
`idempotencyKey`, or `supersedeOnUserComment`.
For the three contract-specific interaction kinds, you can also use
`ask-user-questions-template`, `suggest-tasks-template`, or
`request-confirmation-template`.
If you want the helper to generate the payload and apply it to the current issue in
one step, use `issue-comment-current-template`, `issue-update-current-template`, or
`issue-interaction-current-template`, or `issue-blocked-current-template`.
If the blocker lives outside the shell and must be handed to a Paperclip operator,
use `paperclip-operator-unblock.sh` to print the exact status payload, adapter JSON,
and replay commands without rebuilding them by hand.
Run `./scripts/test-paperclip-helpers.sh` to smoke-test the helper CLI surface
before relying on it in a live heartbeat.
