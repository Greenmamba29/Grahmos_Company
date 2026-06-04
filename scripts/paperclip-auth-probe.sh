#!/usr/bin/env bash

set -euo pipefail

API_URL="${PAPERCLIP_API_URL:-}"
COMPANY_ID="${PAPERCLIP_COMPANY_ID:-}"
RUN_ID="${PAPERCLIP_RUN_ID:-}"
WORKSPACE_CWD="${PAPERCLIP_WORKSPACE_CWD:-}"
COOKIE_JAR=""
SHOW_HEADERS=0

usage() {
  cat <<'EOF'
Usage: paperclip-auth-probe.sh [--cookie-jar PATH] [--show-headers]

Probes the current Paperclip runtime from a cloud-agent shell and reports
whether the shell has enough authentication to access issue/run APIs.

Options:
  --cookie-jar PATH   Reuse or write a curl cookie jar for authenticated probes.
  --show-headers      Print response headers for each request.
  -h, --help          Show this help text.
EOF
}

while (($# > 0)); do
  case "$1" in
    --cookie-jar)
      COOKIE_JAR="${2:-}"
      shift 2
      ;;
    --show-headers)
      SHOW_HEADERS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$API_URL" || -z "$COMPANY_ID" || -z "$RUN_ID" || -z "$WORKSPACE_CWD" ]]; then
  echo "Missing one or more PAPERCLIP_* environment variables." >&2
  echo "Required: PAPERCLIP_API_URL, PAPERCLIP_COMPANY_ID, PAPERCLIP_RUN_ID, PAPERCLIP_WORKSPACE_CWD" >&2
  exit 2
fi

WORKSPACE_ID="${WORKSPACE_CWD##*/}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -n "$COOKIE_JAR" ]]; then
  mkdir -p "$(dirname "$COOKIE_JAR")"
  touch "$COOKIE_JAR"
fi

request() {
  local name="$1"
  local path="$2"
  local body_file="$TMP_DIR/${name}.body"
  local header_file="$TMP_DIR/${name}.headers"
  local curl_args=(
    -sS -L
    -H "Accept: application/json"
    -D "$header_file"
    -o "$body_file"
  )

  if [[ -n "$COOKIE_JAR" ]]; then
    curl_args+=(-b "$COOKIE_JAR" -c "$COOKIE_JAR")
  fi

  local status
  status="$(curl "${curl_args[@]}" -w '%{http_code}' "${API_URL%/}${path}")"
  python3 - "$name" "$path" "$status" "$body_file" "$header_file" "$SHOW_HEADERS" <<'PY'
import json
import sys
from pathlib import Path

name, path, status, body_path, header_path, show_headers = sys.argv[1:]
body_text = Path(body_path).read_text(errors="replace").strip()
headers = Path(header_path).read_text(errors="replace").strip()
summary = body_text

try:
    parsed = json.loads(body_text) if body_text else None
except Exception:
    parsed = None

if isinstance(parsed, dict):
    if isinstance(parsed.get("error"), str):
        summary = parsed["error"]
    elif isinstance(parsed.get("message"), str):
        summary = parsed["message"]
    else:
        summary = json.dumps(parsed)[:300]
else:
    summary = body_text[:300]

print(f"[{name}] {status} {path}")
if summary:
    print(f"  body: {summary}")
if show_headers == "1" and headers:
    print("  headers:")
    for line in headers.splitlines():
        print(f"    {line}")
PY
}

echo "Paperclip auth probe"
echo "  api_url: ${API_URL%/}"
echo "  company_id: ${COMPANY_ID}"
echo "  run_id: ${RUN_ID}"
echo "  workspace_id: ${WORKSPACE_ID}"
if [[ -n "$COOKIE_JAR" ]]; then
  echo "  cookie_jar: ${COOKIE_JAR}"
fi
echo

request "session" "/api/auth/get-session"
request "run" "/api/heartbeat-runs/${RUN_ID}"
request "issues-by-workspace" "/api/companies/${COMPANY_ID}/issues?executionWorkspaceId=${WORKSPACE_ID}&limit=1"

echo
python3 - "$TMP_DIR/session.body" "$TMP_DIR/run.body" "$TMP_DIR/issues-by-workspace.body" <<'PY'
import json
import sys
from pathlib import Path

def load(path: str):
    text = Path(path).read_text(errors="replace").strip()
    try:
        return json.loads(text), text
    except Exception:
        return None, text

session_json, session_text = load(sys.argv[1])
run_json, run_text = load(sys.argv[2])
issues_json, issues_text = load(sys.argv[3])

def error_text(payload, raw):
    if isinstance(payload, dict):
        for key in ("error", "message"):
            value = payload.get(key)
            if isinstance(value, str):
                return value
    return raw

session_error = error_text(session_json, session_text)
run_error = error_text(run_json, run_text)
issues_error = error_text(issues_json, issues_text)

if "Board authentication required" in session_error:
    print("Result: BLOCKED")
    print("Reason: board authentication is required before shell requests can comment on or update issues.")
    print("Owner: Paperclip board admin/operator")
    print("Action: provide a supported authenticated automation path (browser session, MCP, or documented API auth).")
elif isinstance(session_json, dict) and session_json:
    print("Result: AUTHENTICATED")
    print("Reason: auth session payload is present; retry issue/run operations with the same cookie jar.")
else:
    print("Result: UNKNOWN")
    print(f"Session response: {session_error[:300]}")
    if run_error:
        print(f"Run response: {run_error[:300]}")
    if issues_error:
        print(f"Issues response: {issues_error[:300]}")
PY
