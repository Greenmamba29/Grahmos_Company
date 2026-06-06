#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_BUNDLE="$ROOT_DIR/docs/paperclip-artifact-schemas.json"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-validate-json-output.sh [--json] JSON_FILE [EXPECTED_ARTIFACT_TYPE]

Examples:
  ./scripts/paperclip-validate-json-output.sh reports/osiris-paperclip-runtime-latest.json
  ./scripts/paperclip-validate-json-output.sh \
    --json \
    reports/osiris-paperclip-runtime-latest.json \
    paperclip_runtime_latest_manifest

Notes:
  - Validates one JSON file against the checked-in schema bundle.
  - If EXPECTED_ARTIFACT_TYPE is provided, the validator checks that too.
EOF
}

json_mode=0
case "${1:-}" in
  --json)
    json_mode=1
    shift
    ;;
esac

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  usage
  exit 0
fi

json_file="${1:-}"
expected_artifact_type="${2:-}"

if [[ -z "$json_file" ]]; then
  echo "error: JSON_FILE is required" >&2
  exit 2
fi

if [[ ! -f "$SCHEMA_BUNDLE" ]]; then
  echo "error: missing schema bundle: $SCHEMA_BUNDLE" >&2
  exit 1
fi

python3 - "$json_file" "$SCHEMA_BUNDLE" "$expected_artifact_type" "$json_mode" <<'PY'
import json
import sys
from pathlib import Path

json_path = Path(sys.argv[1]).resolve()
schema_bundle_path = Path(sys.argv[2]).resolve()
expected_artifact_type = sys.argv[3]
json_mode = sys.argv[4] == "1"

errors: list[str] = []
warnings: list[str] = []
checks: list[str] = []


def record(ok: bool, message: str):
    if ok:
        checks.append(message)
    else:
        errors.append(message)


def load_json(path: Path, kind: str):
    try:
        return json.loads(path.read_text())
    except Exception as exc:
        errors.append(f"{kind} is valid JSON: {exc}")
        return None


def has_required(obj: dict, fields: dict[str, str], prefix: str = ""):
    for key in fields:
        record(key in obj, f"{prefix}{key} exists")


schema_bundle = load_json(schema_bundle_path, "schema bundle")
data = load_json(json_path, "target JSON")

if schema_bundle is None or data is None:
    result = {
        "schema_version": 1,
        "artifact_type": "paperclip_json_validation_result",
        "json_file": str(json_path),
        "valid": False,
        "checks": checks,
        "warnings": warnings,
        "errors": errors,
    }
    if json_mode:
        json.dump(result, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        for item in errors:
            print(f"FAIL: {item}")
    raise SystemExit(1)

schemas = schema_bundle.get("schemas", {})
artifact_type = data.get("artifact_type")
record(isinstance(artifact_type, str) and artifact_type in schemas, f"artifact_type is supported: {artifact_type}")

if expected_artifact_type:
    record(artifact_type == expected_artifact_type, f"artifact_type matches expected: {expected_artifact_type}")

schema = schemas.get(artifact_type or "", {})
required_fields = schema.get("required_fields", {})
if isinstance(required_fields, dict):
    has_required(data, required_fields)

if artifact_type == "paperclip_runtime_diagnosis":
    allowed = set(schema.get("heartbeat_next_action_state_values", []))
    record(data.get("heartbeat_next_action_state") in allowed, "runtime diagnosis heartbeat_next_action_state is allowed")

if artifact_type == "paperclip_runtime_snapshot":
    record(isinstance(data.get("runtime"), dict), "runtime snapshot runtime is object")
    record(isinstance(data.get("unblock"), dict), "runtime snapshot unblock is object")

if artifact_type == "paperclip_blocked_issue_update_payload":
    record(data.get("status") == "blocked", "blocked payload status is blocked")
    record(isinstance(data.get("comment"), str) and len(data["comment"]) > 0, "blocked payload comment is non-empty")

if artifact_type == "paperclip_runtime_latest_manifest":
    latest = data.get("latest", {})
    file_metadata = data.get("file_metadata", {})
    runtime = data.get("runtime", {})
    record(isinstance(latest, dict), "latest manifest latest is object")
    record(isinstance(file_metadata, dict), "latest manifest file_metadata is object")
    record(isinstance(runtime, dict), "latest manifest runtime is object")
    for key in schema.get("latest_fields", {}):
        record(key in latest, f"latest manifest latest.{key} exists")
    for key, meta in file_metadata.items():
        record(isinstance(meta, dict), f"latest manifest file_metadata.{key} is object")
        for field in schema.get("file_metadata_entry", {}):
            record(field in meta, f"latest manifest file_metadata.{key}.{field} exists")

if artifact_type == "paperclip_refresh_result":
    record(isinstance(data.get("latest_manifest"), dict), "refresh result latest_manifest is object")
    record(data.get("latest_manifest", {}).get("artifact_type") == "paperclip_runtime_latest_manifest", "refresh result latest_manifest artifact_type matches")
    record(isinstance(data.get("validation_result"), dict), "refresh result validation_result is object")
    record(data.get("validation_result", {}).get("artifact_type") == "paperclip_artifact_validation_result", "refresh result validation_result artifact_type matches")

if artifact_type == "paperclip_heartbeat_next_action":
    allowed_dispositions = set(schema.get("heartbeat_disposition_values", []))
    allowed_actions = set(schema.get("next_action_state_values", []))
    disposition = data.get("heartbeat_disposition")
    action = data.get("next_action_state")
    record(disposition in allowed_dispositions, "heartbeat next action disposition is allowed")
    record(action in allowed_actions, "heartbeat next action next_action_state is allowed")
    conditional = schema.get("conditional_fields", {})
    if disposition == "blocked":
      for key in conditional.get("blocked", {}):
          record(key in data, f"heartbeat blocked field {key} exists")
    if disposition == "session_only":
      for key in conditional.get("session_only", {}):
          record(key in data, f"heartbeat session_only field {key} exists")
    if disposition == "ready":
      for key in conditional.get("ready", {}):
          record(key in data, f"heartbeat ready field {key} exists")

if artifact_type == "paperclip_artifact_validation_result":
    record(isinstance(data.get("checks"), list), "validation result checks is list")
    record(isinstance(data.get("warnings"), list), "validation result warnings is list")
    record(isinstance(data.get("errors"), list), "validation result errors is list")

result = {
    "schema_version": 1,
    "artifact_type": "paperclip_json_validation_result",
    "json_file": str(json_path),
    "expected_artifact_type": expected_artifact_type or None,
    "detected_artifact_type": artifact_type,
    "valid": len(errors) == 0,
    "checks": checks,
    "warnings": warnings,
    "errors": errors,
}

if json_mode:
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
else:
    print(f"Validated JSON artifact {json_path}")
    for item in checks:
        print(f"PASS: {item}")
    for item in warnings:
        print(f"WARN: {item}")
    for item in errors:
        print(f"FAIL: {item}")

raise SystemExit(0 if not errors else 1)
PY
