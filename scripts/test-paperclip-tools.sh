#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

bash -n ./scripts/paperclip-api.sh ./scripts/paperclip-runtime-check.sh
./scripts/test-paperclip-api.sh
./scripts/test-paperclip-runtime-check.sh

echo "paperclip tool verification passed"
