#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_CHECK="$ROOT_DIR/scripts/paperclip-runtime-check.sh"
UNBLOCK_HELPER="$ROOT_DIR/scripts/paperclip-operator-unblock.sh"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-write-runtime-report.sh OUTPUT_PATH [PAPERCLIP_SECRET_ID] [CURSOR_SECRET_ID]

Examples:
  ./scripts/paperclip-write-runtime-report.sh reports/osiris-paperclip-runtime-report.md
  ./scripts/paperclip-write-runtime-report.sh \
    reports/osiris-paperclip-runtime-report.md \
    osiris-paperclip-agent-key-secret-id \
    cursor-api-key-secret-id

Notes:
  - The report captures the current runtime check output and the operator unblock handoff.
  - Non-zero runtime-check exits are preserved in the report because blocked runs are expected.
  - The helper creates the parent directory for OUTPUT_PATH when needed.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  usage
  exit 0
fi

output_path="${1:-}"
paperclip_secret_id="${2:-YOUR_PAPERCLIP_SECRET_ID}"
cursor_secret_id="${3:-YOUR_CURSOR_SECRET_ID}"

if [[ -z "$output_path" ]]; then
  echo "error: OUTPUT_PATH is required" >&2
  exit 2
fi

if [[ ! -x "$RUNTIME_CHECK" ]]; then
  echo "error: missing helper: $RUNTIME_CHECK" >&2
  exit 1
fi

if [[ ! -x "$UNBLOCK_HELPER" ]]; then
  echo "error: missing helper: $UNBLOCK_HELPER" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_path")"

runtime_output_file="$(mktemp)"
unblock_output_file="$(mktemp)"

runtime_status=0
if "$RUNTIME_CHECK" >"$runtime_output_file" 2>&1; then
  runtime_status=0
else
  runtime_status=$?
fi

unblock_status=0
if "$UNBLOCK_HELPER" "$paperclip_secret_id" "$cursor_secret_id" >"$unblock_output_file" 2>&1; then
  unblock_status=0
else
  unblock_status=$?
fi

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
branch_name="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
commit_sha="$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"

{
  cat <<EOF
# Osiris Hermes Paperclip Runtime Report

- Generated at: $timestamp
- Git branch: $branch_name
- Git commit: $commit_sha
- Runtime check exit code: $runtime_status
- Operator handoff exit code: $unblock_status

## Runtime check output

\`\`\`text
EOF
  sed -n '1,240p' "$runtime_output_file"
  cat <<'EOF'
```

## Operator unblock handoff

```text
EOF
  sed -n '1,240p' "$unblock_output_file"
  cat <<'EOF'
```
EOF
} >"$output_path"

rm -f "$runtime_output_file" "$unblock_output_file"

printf 'Wrote %s\n' "$output_path"
