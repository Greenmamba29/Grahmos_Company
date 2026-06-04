# Grahmos_Company

This is the Company run main repo for Grahmos.

## Paperclip runtime diagnostics

- Run `./scripts/paperclip-runtime-check.sh` inside a Paperclip-managed runtime to
  verify whether control-plane auth is available for issue updates.
- If the script reports that `PAPERCLIP_API_KEY` is missing, the agent can still
  work on the Git repository but cannot read or mutate Paperclip issues until the
  Cursor Cloud adapter injects that variable.
- Once auth is available, use `./scripts/paperclip-api.sh` for the common Paperclip
  operations needed during heartbeats:
  - `health`
  - `me`
  - `inbox-lite`
  - `issue-get ISSUE_ID`
  - `issue-comments ISSUE_ID [AFTER_COMMENT_ID]`
  - `issue-update ISSUE_ID JSON_FILE|-`
  - `issue-blocked ISSUE_ID UNBLOCK_OWNER REQUIRED_ACTION [DETAILS]`
