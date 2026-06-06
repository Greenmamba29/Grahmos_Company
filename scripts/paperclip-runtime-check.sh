#!/usr/bin/env bash
set -euo pipefail

show_var() {
  local name="$1"
  local value="${!name:-}"
  if [[ -n "$value" ]]; then
    printf '%s: present len=%s\n' "$name" "${#value}"
  else
    printf '%s: missing\n' "$name"
  fi
}

echo "Paperclip runtime diagnostic"
echo "============================"
show_var PAPERCLIP_AGENT_ID
show_var PAPERCLIP_COMPANY_ID
show_var PAPERCLIP_RUN_ID
show_var PAPERCLIP_WAKE_REASON
show_var PAPERCLIP_API_URL
show_var PAPERCLIP_API_KEY
show_var PAPERCLIP_TASK_ID
show_var PAPERCLIP_WAKE_COMMENT_ID
show_var PAPERCLIP_APPROVAL_ID
show_var PAPERCLIP_APPROVAL_STATUS
show_var PAPERCLIP_LINKED_ISSUE_IDS

echo
if [[ -z "${PAPERCLIP_API_URL:-}" ]]; then
  echo "Result: PAPERCLIP_API_URL missing. This does not look like a Paperclip runtime."
  exit 1
fi

health_code="$(curl -sSL -o /tmp/paperclip-health.out -w '%{http_code}' \
  "$PAPERCLIP_API_URL/api/health" || true)"
echo "Health endpoint: HTTP $health_code"
sed -n '1,20p' /tmp/paperclip-health.out

echo
if [[ -z "${PAPERCLIP_API_KEY:-}" ]]; then
  echo "Result: control-plane auth unavailable."
  echo "Next action: inject PAPERCLIP_API_KEY into the agent adapter env."
  exit 2
fi

agent_code="$(curl -sSL -o /tmp/paperclip-agent-me.out -w '%{http_code}' \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  "$PAPERCLIP_API_URL/api/agents/me" || true)"
echo "Agent identity endpoint: HTTP $agent_code"
sed -n '1,40p' /tmp/paperclip-agent-me.out

if [[ "$agent_code" != "200" ]]; then
  echo
  echo "Result: bearer token present but agent auth failed."
  exit 3
fi

echo
echo "Result: control-plane auth available."
