# Grahmos_Company

This is the Company run main repo for Grahmos.

## Paperclip runtime diagnostics

- Run `./scripts/paperclip-runtime-check.sh` inside a Paperclip-managed runtime to
  verify whether the shell can access issue state through a board-authenticated
  session or a `PAPERCLIP_API_KEY` bearer token.
- Run `./scripts/paperclip-api.sh sample-payload TYPE` to print valid JSON examples
  for the most common execution-contract actions before piping them into the live
  comment/update/interaction commands.
- If the script exits with `2`, the agent can still work on the Git repository but
  cannot read or mutate Paperclip issues from the shell yet.
- Once auth is available, use `./scripts/paperclip-api.sh` for the common Paperclip
  operations needed during heartbeats:
  - `health`
  - `session`
  - `me`
  - `inbox-lite`
  - `current-issue-id`
  - `issue-get ISSUE_ID`
  - `issue-comments ISSUE_ID [AFTER_COMMENT_ID]`
  - `issue-comment ISSUE_ID JSON_FILE|-`
  - `issue-comment-current JSON_FILE|-`
  - `issue-update ISSUE_ID JSON_FILE|-`
  - `issue-update-current JSON_FILE|-`
  - `issue-interaction ISSUE_ID JSON_FILE|-`
  - `issue-interaction-current JSON_FILE|-`
  - `issue-blocked ISSUE_ID UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`
  - `issue-blocked-current UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`

The comment helper accepts the raw JSON body expected by `POST /api/issues/{issueId}/comments`,
so it can carry structured fields such as `resume`, `reopen`, or `interrupt` when
the execution contract requires them.
The interaction helpers accept the raw JSON body expected by
`POST /api/issues/{issueId}/interactions`, which is useful for
`suggest_tasks`, `ask_user_questions`, and `request_confirmation`.
The same helper also supports listing interactions and driving the follow-up
lifecycle through accept, reject, cancel, and respond commands once an
interaction exists.
Useful examples:
- `./scripts/paperclip-api.sh issue-comment-resume-current`
- `./scripts/paperclip-api.sh issue-done-current "Completed and verified."`
- `./scripts/paperclip-api.sh sample-payload comment-resume | ./scripts/paperclip-api.sh issue-comment-current -`
- `./scripts/paperclip-api.sh sample-payload update-done | ./scripts/paperclip-api.sh issue-update-current -`
- `./scripts/paperclip-api.sh build-markdown-document plan.md "Implementation plan" "Initial plan draft"`
- `./scripts/paperclip-api.sh issue-document-put-markdown-current plan plan.md "Implementation plan" "Initial plan draft"`
- `./scripts/paperclip-api.sh sample-payload plan-document | ./scripts/paperclip-api.sh issue-document-put-current plan -`
- `./scripts/paperclip-api.sh build-plan-confirmation REVISION_ID ISSUE-123 | ./scripts/paperclip-api.sh issue-interaction-current -`
- `./scripts/paperclip-api.sh issue-plan-confirmation-current ISSUE-123`
- `./scripts/paperclip-api.sh issue-plan-from-markdown-current ISSUE-123 plan.md "Implementation plan" "Initial plan draft"`
- `./scripts/paperclip-api.sh sample-payload request-confirmation | ./scripts/paperclip-api.sh issue-interaction-current -`
- `./scripts/paperclip-api.sh issue-interactions-current`
- `./scripts/paperclip-api.sh sample-payload interaction-respond | ./scripts/paperclip-api.sh issue-interaction-respond-current INTERACTION_ID -`

The document helpers are useful for the plan-approval flow because the execution
contract requires updating the `plan` document before creating a
`request_confirmation` interaction bound to the latest plan revision. The
`build-plan-confirmation` helper fills in the idempotency key and target revision
for that flow, while `issue-plan-confirmation-current` performs the full
"resolve latest plan revision -> create confirmation" flow in one command once
auth is available.
If you already have the plan in a markdown file, `issue-document-put-markdown-current`
is the simplest way to save it without building the JSON envelope by hand.
If you also want to immediately create the approval request after saving that
plan, `issue-plan-from-markdown-current` performs the full flow in one command
once auth is available.

For the most common execution-contract actions, prefer the direct wrappers:
- `issue-comment-resume-current`
- `issue-done-current`

Quick regression check:
- `./scripts/test-paperclip-helpers.sh`
