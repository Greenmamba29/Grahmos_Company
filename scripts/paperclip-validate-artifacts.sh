#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_BUNDLE="$ROOT_DIR/docs/paperclip-artifact-schemas.json"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/paperclip-validate-artifacts.sh [--json] [TARGET_DIR]

Examples:
  ./scripts/paperclip-validate-artifacts.sh
  ./scripts/paperclip-validate-artifacts.sh reports
  ./scripts/paperclip-validate-artifacts.sh --json reports

Notes:
  - TARGET_DIR defaults to reports.
  - Validates the canonical artifact set plus the newest archived copies referenced
    by osiris-paperclip-runtime-latest.json.
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

target_dir="${1:-reports}"

if [[ ! -f "$SCHEMA_BUNDLE" ]]; then
  echo "error: missing schema bundle: $SCHEMA_BUNDLE" >&2
  exit 1
fi

python3 - "$ROOT_DIR" "$target_dir" "$SCHEMA_BUNDLE" "$json_mode" <<'PY'
import hashlib
import json
import os
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
target_dir = Path(sys.argv[2]).resolve()
schema_bundle_path = Path(sys.argv[3]).resolve()
json_mode = sys.argv[4] == "1"

errors: list[str] = []
warnings: list[str] = []
checks: list[str] = []


def record(ok: bool, message: str):
    if ok:
        checks.append(message)
    else:
        errors.append(message)


def require_path(path: Path, kind: str):
    record(path.exists(), f"{kind} exists: {path}")
    return path.exists()


def load_json(path: Path, kind: str):
    if not require_path(path, kind):
        return None
    try:
        return json.loads(path.read_text())
    except Exception as exc:
        errors.append(f"{kind} is valid JSON: {exc}")
        return None


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rel_to_root(path: Path) -> str:
    return os.path.relpath(path, root)


schema_bundle = load_json(schema_bundle_path, "schema bundle")
if schema_bundle is not None:
    record(schema_bundle.get("artifact_type") == "paperclip_schema_bundle", "schema bundle artifact_type matches")
    for key in [
        "paperclip_runtime_diagnosis",
        "paperclip_runtime_snapshot",
        "paperclip_blocked_issue_update_payload",
        "paperclip_runtime_latest_manifest",
        "paperclip_refresh_result",
        "paperclip_heartbeat_next_action",
        "paperclip_artifact_validation_result",
        "paperclip_json_validation_result",
    ]:
        record(key in schema_bundle.get("schemas", {}), f"schema bundle includes {key}")

latest_manifest_path = target_dir / "osiris-paperclip-runtime-latest.json"
snapshot_path = target_dir / "osiris-paperclip-runtime-snapshot.json"
blocked_update_path = target_dir / "osiris-paperclip-blocked-update.json"
report_path = target_dir / "osiris-paperclip-runtime-report.md"

latest_manifest = load_json(latest_manifest_path, "latest manifest")
snapshot = load_json(snapshot_path, "runtime snapshot")
blocked_update = load_json(blocked_update_path, "blocked update payload")

if require_path(report_path, "runtime report"):
    try:
        report_text = report_path.read_text()
        record(
            report_text.startswith("# Osiris Hermes Paperclip Runtime Report"),
            "runtime report has expected heading",
        )
    except Exception as exc:
        errors.append(f"runtime report is readable text: {exc}")

if blocked_update is not None:
    record(blocked_update.get("status") == "blocked", "blocked update status is blocked")
    record(isinstance(blocked_update.get("comment"), str) and len(blocked_update["comment"]) > 0, "blocked update comment is non-empty")

if snapshot is not None:
    record(snapshot.get("schema_version") == 1, "runtime snapshot schema_version is 1")
    record(snapshot.get("artifact_type") == "paperclip_runtime_snapshot", "runtime snapshot artifact_type matches")
    record("runtime" in snapshot and isinstance(snapshot["runtime"], dict), "runtime snapshot includes runtime object")
    record("unblock" in snapshot and isinstance(snapshot["unblock"], dict), "runtime snapshot includes unblock object")

if latest_manifest is not None:
    record(latest_manifest.get("schema_version") == 1, "latest manifest schema_version is 1")
    record(latest_manifest.get("artifact_type") == "paperclip_runtime_latest_manifest", "latest manifest artifact_type matches")
    latest = latest_manifest.get("latest", {})
    file_metadata = latest_manifest.get("file_metadata", {})
    runtime = latest_manifest.get("runtime", {})
    record(isinstance(latest, dict), "latest manifest has latest object")
    record(isinstance(file_metadata, dict), "latest manifest has file_metadata object")
    record(isinstance(runtime, dict), "latest manifest has runtime object")
    for key in [
        "report_path",
        "snapshot_path",
        "blocked_update_path",
        "validation_path",
        "latest_manifest_path",
        "latest_archive_dir",
        "archive_report_path",
        "archive_snapshot_path",
        "archive_blocked_update_path",
        "archive_validation_path",
        "archive_manifest_path",
    ]:
        record(key in latest and isinstance(latest.get(key), str) and latest.get(key), f"latest manifest includes {key}")

    latest_archive_dir = Path(latest.get("latest_archive_dir", ""))
    if latest_archive_dir:
        record(latest_archive_dir.is_dir(), f"latest archive dir exists: {latest_archive_dir}")

    expected_paths = {
        "report": report_path.resolve(),
        "snapshot": snapshot_path.resolve(),
        "blocked_update": blocked_update_path.resolve(),
        "validation": (target_dir / "osiris-paperclip-runtime-validation.json").resolve(),
        "archive_report": Path(latest.get("archive_report_path", "")).resolve() if latest.get("archive_report_path") else None,
        "archive_snapshot": Path(latest.get("archive_snapshot_path", "")).resolve() if latest.get("archive_snapshot_path") else None,
        "archive_blocked_update": Path(latest.get("archive_blocked_update_path", "")).resolve() if latest.get("archive_blocked_update_path") else None,
        "archive_validation": Path(latest.get("archive_validation_path", "")).resolve() if latest.get("archive_validation_path") else None,
    }

    for key, path in expected_paths.items():
        if path is None:
            errors.append(f"expected path for {key} missing from latest manifest")
            continue
        record(path.exists(), f"{key} file exists: {path}")
        meta = file_metadata.get(key, {})
        if not path.exists():
            continue
        record(meta.get("path") == str(path), f"{key} metadata path matches")
        record(meta.get("relative_path") == rel_to_root(path), f"{key} metadata relative path matches")
        record(meta.get("size_bytes") == path.stat().st_size, f"{key} metadata size matches")
        record(meta.get("sha256") == sha256(path), f"{key} metadata sha256 matches")

    if snapshot is not None:
        record(runtime.get("diagnosis") == snapshot.get("runtime", {}).get("diagnosis"), "latest manifest diagnosis matches snapshot")
        record(
            runtime.get("heartbeat_next_action_state") == snapshot.get("runtime", {}).get("heartbeat_next_action_state"),
            "latest manifest next action state matches snapshot",
        )
        record(
            runtime.get("issue_operations_blocked") == snapshot.get("runtime", {}).get("issue_operations_blocked"),
            "latest manifest blocked flag matches snapshot",
        )

result = {
    "schema_version": 1,
    "artifact_type": "paperclip_artifact_validation_result",
    "target_dir": str(target_dir),
    "valid": len(errors) == 0,
    "checks": checks,
    "warnings": warnings,
    "errors": errors,
}

if json_mode:
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
else:
    print(f"Validated Paperclip artifacts in {target_dir}")
    for item in checks:
        print(f"PASS: {item}")
    for item in warnings:
        print(f"WARN: {item}")
    for item in errors:
        print(f"FAIL: {item}")

raise SystemExit(0 if not errors else 1)
PY
