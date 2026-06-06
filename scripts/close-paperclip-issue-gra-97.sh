#!/usr/bin/env bash
set -euo pipefail

ISSUE_ID="${1:-GRA-97}"
API_URL="${PAPERCLIP_API_URL:-}"
RUN_ID="${PAPERCLIP_RUN_ID:-}"
API_KEY="${PAPERCLIP_API_KEY:-}"
API_KEY_FILE="${PAPERCLIP_API_KEY_FILE:-}"

if [[ -z "$API_URL" ]]; then
  echo "error: PAPERCLIP_API_URL is required" >&2
  exit 1
fi

if [[ -z "$RUN_ID" ]]; then
  echo "error: PAPERCLIP_RUN_ID is required" >&2
  exit 1
fi

if [[ -z "$API_KEY" && -n "$API_KEY_FILE" && -f "$API_KEY_FILE" ]]; then
  API_KEY="$(<"$API_KEY_FILE")"
fi

if [[ -z "$API_KEY" ]]; then
  echo "error: PAPERCLIP_API_KEY or PAPERCLIP_API_KEY_FILE is required" >&2
  exit 1
fi

COMMENT_BODY="$(cat <<'EOF'
## Update
- Completed the productivity review for `GRA-75` and captured it in `reports/GRA-97-productivity-review.md`.
- Reviewed the two GRA-75 draft PRs and their report revisions:
  - PR #44 / commit `826d780`
  - PR #46 / commit `9779e68`
- Conclusion: `GRA-75` showed moderate productivity with avoidable rework. The later review was materially stronger and reached the correct `done` disposition for the source review task.
- Recommendation: mark both `GRA-75` and `GRA-97` as `done`.
EOF
)"
export COMMENT_BODY

PAYLOAD_FILE="$(mktemp)"
trap 'rm -f "$PAYLOAD_FILE"' EXIT

python3 - <<'PY' >"$PAYLOAD_FILE"
import json
import os

print(json.dumps({
    "status": "done",
    "comment": os.environ["COMMENT_BODY"],
}))
PY

curl -sS -X PATCH \
  -H "Authorization: Bearer $API_KEY" \
  -H "X-Paperclip-Run-Id: $RUN_ID" \
  -H "Content-Type: application/json" \
  "$API_URL/api/issues/$ISSUE_ID" \
  --data-binary @"$PAYLOAD_FILE"
echo
