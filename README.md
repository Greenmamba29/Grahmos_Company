# Grahmos_Company

This is the Company run main repo for Grahmos.

## Paperclip runtime diagnostics

- Run `./scripts/paperclip-runtime-check.sh` inside a Paperclip-managed runtime to
  verify whether control-plane auth is available for issue updates.
- If the script reports that `PAPERCLIP_API_KEY` is missing, the agent can still
  work on the Git repository but cannot read or mutate Paperclip issues until the
  Cursor Cloud adapter injects that variable.
