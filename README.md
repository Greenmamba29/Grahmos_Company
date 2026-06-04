# Grahmos_Company

This repository is the minimal GrahmOS company bootstrap used by Cursor Cloud
and Paperclip. It stores the root agent instructions plus the company-level
Paperclip setup skill that documents how the GrahmOS automation stack is wired.

## Repository contents

- `AGENTS.md` - root instructions injected into Cursor Cloud coding sessions
- `skills/grahmmos-paperclip/SKILL.md` - Paperclip deployment and operations
  reference for GrahmOS
- `scripts/paperclip-runtime-check.sh` - shell-side diagnostic for Paperclip
  runtime health and board-auth availability

## Paperclip runtime diagnostic

When a cloud agent has the Paperclip runtime environment variables but cannot
read or update issue state, run:

```bash
./scripts/paperclip-runtime-check.sh
```

The script verifies:

- required `PAPERCLIP_*` environment variables are present
- the Paperclip `/api/health` endpoint is reachable
- the current shell has a board-authenticated session
- the current heartbeat run can resolve its issue list

Exit codes:

- `0` - runtime is healthy and issue lookup works
- `1` - runtime or endpoint failure
- `2` - board authentication is missing, so issue operations will fail from the
  shell even though the runtime is otherwise reachable
