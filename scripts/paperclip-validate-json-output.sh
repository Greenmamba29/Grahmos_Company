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
    for key, spec in fields.items():
        record(key in obj, f"{prefix}{key} exists")
        if key in obj:
            check_value_against_spec(obj[key], spec, f"{prefix}{key}")


def check_value_against_spec(value, spec: str, prefix: str):
    if spec == "string":
        record(isinstance(value, str), f"{prefix} is string")
        return
    if spec == "integer":
        record(isinstance(value, int) and not isinstance(value, bool), f"{prefix} is integer")
        return
    if spec == "boolean":
        record(isinstance(value, bool), f"{prefix} is boolean")
        return
    if spec == "object":
        record(isinstance(value, dict), f"{prefix} is object")
        return
    if spec == "string[]":
        record(isinstance(value, list), f"{prefix} is list")
        if isinstance(value, list):
            record(all(isinstance(item, str) for item in value), f"{prefix} items are strings")
        return
    if spec == "string|null":
        record(value is None or isinstance(value, str), f"{prefix} is string or null")
        return
    if spec.startswith('"') and spec.endswith('"'):
        literal = spec[1:-1]
        record(value == literal, f"{prefix} matches literal {literal}")
        return
    if spec.endswith(" object"):
        artifact_type = spec[: -len(" object")]
        validate_artifact(value, artifact_type, prefix + ".")
        return
    warnings.append(f"{prefix} has unhandled schema spec: {spec}")


def validate_blocked_payload(obj: dict, prefix: str = ""):
    if not isinstance(obj, dict):
        record(False, f"{prefix}blocked payload is object")
        return
    record(obj.get("status") == "blocked", f"{prefix}blocked payload status is blocked")
    record(isinstance(obj.get("comment"), str) and len(obj["comment"]) > 0, f"{prefix}blocked payload comment is non-empty")


def validate_artifact(obj: dict, expected_type: str | None = None, prefix: str = ""):
    if not isinstance(obj, dict):
        record(False, f"{prefix}artifact is object")
        return None

    artifact_type = obj.get("artifact_type")
    if isinstance(artifact_type, str) and artifact_type in schemas:
        record(True, f"{prefix}artifact_type is supported: {artifact_type}")
    elif expected_type and expected_type in schemas:
        warnings.append(f"{prefix}artifact_type missing or unsupported; using expected artifact type {expected_type}")
        artifact_type = expected_type
    else:
        record(False, f"{prefix}artifact_type is supported: {artifact_type}")

    if expected_type:
        record(artifact_type == expected_type, f"{prefix}artifact_type matches expected: {expected_type}")

    schema = schemas.get(artifact_type or "", {})
    required_fields = schema.get("required_fields", {})
    if isinstance(required_fields, dict):
        has_required(obj, required_fields, prefix)

    if artifact_type == "paperclip_runtime_diagnosis":
        allowed = set(schema.get("heartbeat_next_action_state_values", []))
        record(obj.get("heartbeat_next_action_state") in allowed, f"{prefix}runtime diagnosis heartbeat_next_action_state is allowed")

    if artifact_type == "paperclip_runtime_snapshot":
        record(isinstance(obj.get("runtime"), dict), f"{prefix}runtime snapshot runtime is object")
        record(isinstance(obj.get("unblock"), dict), f"{prefix}runtime snapshot unblock is object")
        validate_artifact(obj.get("runtime"), "paperclip_runtime_diagnosis", prefix + "runtime.")
        unblock = obj.get("unblock", {})
        if isinstance(unblock, dict) and "blocked_issue_payload" in unblock:
            validate_blocked_payload(unblock.get("blocked_issue_payload"), prefix + "unblock.")

    if artifact_type == "paperclip_blocked_issue_update_payload":
        validate_blocked_payload(obj, prefix)

    if artifact_type == "paperclip_runtime_latest_manifest":
        latest = obj.get("latest", {})
        file_metadata = obj.get("file_metadata", {})
        runtime = obj.get("runtime", {})
        record(isinstance(latest, dict), f"{prefix}latest manifest latest is object")
        record(isinstance(file_metadata, dict), f"{prefix}latest manifest file_metadata is object")
        record(isinstance(runtime, dict), f"{prefix}latest manifest runtime is object")
        for key, spec in schema.get("latest_fields", {}).items():
            record(key in latest, f"{prefix}latest manifest latest.{key} exists")
            if key in latest:
                check_value_against_spec(latest[key], spec, f"{prefix}latest manifest latest.{key}")
        for key, meta in file_metadata.items():
            record(isinstance(meta, dict), f"{prefix}latest manifest file_metadata.{key} is object")
            for field, spec in schema.get("file_metadata_entry", {}).items():
                record(field in meta, f"{prefix}latest manifest file_metadata.{key}.{field} exists")
                if field in meta:
                    check_value_against_spec(meta[field], spec, f"{prefix}latest manifest file_metadata.{key}.{field}")

    if artifact_type == "paperclip_refresh_result":
        record(isinstance(obj.get("latest_manifest"), dict), f"{prefix}refresh result latest_manifest is object")
        record(obj.get("latest_manifest", {}).get("artifact_type") == "paperclip_runtime_latest_manifest", f"{prefix}refresh result latest_manifest artifact_type matches")
        record(isinstance(obj.get("validation_result"), dict), f"{prefix}refresh result validation_result is object")
        record(obj.get("validation_result", {}).get("artifact_type") == "paperclip_artifact_validation_result", f"{prefix}refresh result validation_result artifact_type matches")
        validate_artifact(obj.get("latest_manifest"), "paperclip_runtime_latest_manifest", prefix + "latest_manifest.")
        validate_artifact(obj.get("validation_result"), "paperclip_artifact_validation_result", prefix + "validation_result.")

    if artifact_type == "paperclip_heartbeat_next_action":
        allowed_dispositions = set(schema.get("heartbeat_disposition_values", []))
        allowed_actions = set(schema.get("next_action_state_values", []))
        disposition = obj.get("heartbeat_disposition")
        action = obj.get("next_action_state")
        record(disposition in allowed_dispositions, f"{prefix}heartbeat next action disposition is allowed")
        record(action in allowed_actions, f"{prefix}heartbeat next action next_action_state is allowed")
        validate_artifact(obj.get("diagnosis"), "paperclip_runtime_diagnosis", prefix + "diagnosis.")
        conditional = schema.get("conditional_fields", {})
        if disposition == "blocked":
            for key, spec in conditional.get("blocked", {}).items():
                record(key in obj, f"{prefix}heartbeat blocked field {key} exists")
                if key in obj:
                    check_value_against_spec(obj[key], spec, f"{prefix}heartbeat blocked field {key}")
            validate_artifact(obj.get("latest_manifest"), "paperclip_runtime_latest_manifest", prefix + "latest_manifest.")
            validate_blocked_payload(obj.get("blocked_update_payload"), prefix)
            validate_artifact(obj.get("refresh_result"), "paperclip_refresh_result", prefix + "refresh_result.")
        if disposition == "session_only":
            for key, spec in conditional.get("session_only", {}).items():
                record(key in obj, f"{prefix}heartbeat session_only field {key} exists")
                if key in obj:
                    check_value_against_spec(obj[key], spec, f"{prefix}heartbeat session_only field {key}")
        if disposition == "ready":
            for key, spec in conditional.get("ready", {}).items():
                record(key in obj, f"{prefix}heartbeat ready field {key} exists")
                if key in obj:
                    check_value_against_spec(obj[key], spec, f"{prefix}heartbeat ready field {key}")

    if artifact_type == "paperclip_artifact_validation_result":
        record(isinstance(obj.get("checks"), list), f"{prefix}validation result checks is list")
        record(isinstance(obj.get("warnings"), list), f"{prefix}validation result warnings is list")
        record(isinstance(obj.get("errors"), list), f"{prefix}validation result errors is list")

    if artifact_type == "paperclip_json_validation_result":
        record(isinstance(obj.get("checks"), list), f"{prefix}json validation result checks is list")
        record(isinstance(obj.get("warnings"), list), f"{prefix}json validation result warnings is list")
        record(isinstance(obj.get("errors"), list), f"{prefix}json validation result errors is list")

    return artifact_type


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
artifact_type = validate_artifact(data, expected_artifact_type or None)

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
