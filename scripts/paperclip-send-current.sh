#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-send-current.sh [--print-command] blocked-current
  ./scripts/paperclip-send-current.sh [--print-command] gra-39-echo-blocked
  ./scripts/paperclip-send-current.sh [--print-command] resume-comment
  ./scripts/paperclip-send-current.sh [--print-command] auth-question

Modes:
  blocked-current  Send the checked-in blocked disposition payload.
  gra-39-echo-blocked
                  Send the checked-in Echo model blocker payload for GRA-39.
  resume-comment   Send the checked-in structured resume comment payload.
  auth-question    Send the checked-in ask_user_questions interaction payload.

Options:
  --print-command  Print the underlying paperclip-api command instead of executing it.
EOF
}

print_only=0
if [[ "${1:-}" == "--print-command" ]]; then
  print_only=1
  shift
fi

mode="${1:-}"
case "$mode" in
  blocked-current)
    cmd=(./scripts/paperclip-api.sh issue-update-current paperclip/payloads/blocked-current.json)
    ;;
  gra-39-echo-blocked)
    cmd=(./scripts/paperclip-api.sh issue-update-current paperclip/payloads/gra-39-echo-model-blocked.json)
    ;;
  resume-comment)
    cmd=(./scripts/paperclip-api.sh issue-comment-current paperclip/payloads/resume-comment.json)
    ;;
  auth-question)
    cmd=(./scripts/paperclip-api.sh issue-interaction-current paperclip/payloads/auth-question.json)
    ;;
  ""|-h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "error: unknown mode: $mode" >&2
    echo >&2
    usage >&2
    exit 2
    ;;
esac

if (( print_only )); then
  printf '%q' "${cmd[0]}"
  for arg in "${cmd[@]:1}"; do
    printf ' %q' "$arg"
  done
  printf '\n'
  exit 0
fi

"${cmd[@]}"
