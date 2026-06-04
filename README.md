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
- `./scripts/paperclip-api.sh sample-payload comment-resume | ./scripts/paperclip-api.sh issue-comment-current -`
- `./scripts/paperclip-api.sh sample-payload update-done | ./scripts/paperclip-api.sh issue-update-current -`
- `./scripts/paperclip-api.sh sample-payload plan-document | ./scripts/paperclip-api.sh issue-document-put-current plan -`
- `./scripts/paperclip-api.sh sample-payload request-confirmation | ./scripts/paperclip-api.sh issue-interaction-current -`
- `./scripts/paperclip-api.sh issue-interactions-current`
- `./scripts/paperclip-api.sh sample-payload interaction-respond | ./scripts/paperclip-api.sh issue-interaction-respond-current INTERACTION_ID -`

The document helpers are useful for the plan-approval flow because the execution
contract requires updating the `plan` document before creating a
`request_confirmation` interaction bound to the latest plan revision.

Quick regression check:
- `./scripts/test-paperclip-helpers.sh`
