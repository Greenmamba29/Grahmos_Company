# Grahmos_Company

This is the Company run main repo for Grahmos.

## Paperclip runtime diagnostics

- Run `./scripts/paperclip-runtime-check.sh` inside a Paperclip-managed runtime to
  verify whether the shell can access issue state through a board-authenticated
  session or a `PAPERCLIP_API_KEY` bearer token.
- Add `--json` when you need the same diagnosis as structured machine-readable data
  for another script or report generator.
- The JSON output includes `heartbeat_next_action_state`, which tells automation
  whether the next step is to refresh blocked artifacts, warn on session-only
  visibility, or switch to the current-issue playbook.
- If the script exits with `2`, the agent can still work on the Git repository but
  cannot read or mutate Paperclip issues from the shell yet.
- Even if `/api/health` is degraded or returns a non-200 status, the runtime check
  still preserves the stronger auth diagnosis when session and issue endpoints
  clearly show a missing Paperclip auth path.
- The runtime check also inspects `CLOUD_AGENT_INJECTED_SECRET_NAMES` so it can say
  whether `PAPERCLIP_API_KEY` was ever injected into the cloud shell at all.
- The runtime check now also tells you whether adding `X-Paperclip-Run-Id` to the
  run issue lookup changed anything; in this environment it does not provide a read
  bypass by itself.
- It also reports whether heartbeat-run log and workspace-operation reads are still
  locked; in this environment those run-scoped debug endpoints remain blocked too.
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
- If you need a durable file artifact for manual escalation or review, run
  `./scripts/paperclip-write-runtime-report.sh OUTPUT_PATH [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]`
  to write the current runtime check output and operator handoff into a markdown
  report.
- If you need the same handoff as structured JSON, run
  `./scripts/paperclip-write-runtime-snapshot.sh OUTPUT_PATH [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]`
  to write a machine-readable runtime snapshot plus unblock payloads.
- If you want the standard markdown and JSON artifacts refreshed together, run
  `./scripts/paperclip-refresh-runtime-artifacts.sh [OUTPUT_DIR] [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]`.
  That also writes `osiris-paperclip-blocked-update.json`, a standalone blocked
  issue-update payload, `osiris-paperclip-runtime-latest.json` as a stable pointer
  to the newest canonical files, plus timestamped archive copies under
  `OUTPUT_DIR/history/`.
- If you want one command that decides the next heartbeat step for you, run
  `./scripts/paperclip-heartbeat-next-action.sh [OUTPUT_DIR] [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]`.
  It runs the JSON diagnosis, refreshes blocked artifacts when auth is missing, and
  only prints the current-issue playbook when the API-helper auth path is actually
  ready. A session-only/read-only state prints a warning instead of pretending issue
  mutations are available.

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
If you need that same information as a checked-in or shareable document,
use `paperclip-write-runtime-report.sh` to write a markdown report file.
If you need it for automation or downstream tooling, use
`paperclip-runtime-check.sh --json` or `paperclip-write-runtime-snapshot.sh`.
If you want to refresh both canonical runtime artifacts in one step, use
`paperclip-refresh-runtime-artifacts.sh`.
If you need the standalone blocked disposition payload as a file, use
`paperclip-write-blocked-update.sh`.
If you want a single blocked-vs-unblocked heartbeat entry point, use
`paperclip-heartbeat-next-action.sh`.
Run `./scripts/test-paperclip-helpers.sh` to smoke-test the helper CLI surface
before relying on it in a live heartbeat.
