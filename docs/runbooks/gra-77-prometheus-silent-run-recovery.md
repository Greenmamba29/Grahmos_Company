# GRA-77 - Review silent active run for Prometheus

## Scope

This note captures the recovery path for the Prometheus silent-run incident reported in the Paperclip wake payload on 2026-06-06.

## Confirmed signals

- Issue: `GRA-77`
- Title: `Review silent active run for Prometheus`
- Silent run: `70ce0dd7-e340-47f3-b77a-77cc0c2f974a`
- Source issue: `GRA-16`
- Last concrete failure: run `def05497-c687-42c5-992f-d2dd882431aa`
- Final error: `adapter_failed`
- Latest error summary: `database is locked`
- Captured output: no adapter-provided result summary and no run-log tail in the wake payload

## Diagnosis

The local workspace does not contain the Paperclip server or adapter source, so this heartbeat could not patch the runtime directly. The failure signature is still specific enough to identify the likely cause:

1. Prometheus runs on a local coding adapter (`Claude Code (local)` in the company setup skill).
2. `database is locked` is a strong match for OpenCode-style SQLite contention (`SQLITE_BUSY`) rather than a Git or workspace failure.
3. The most likely lock target is the shared OpenCode data database under the local agent host, not the company repo in this workspace.
4. A silent active run can happen after the adapter failure if another run record remains marked `running`, or if the original child process never emitted usable log output before dying.

## Most likely root cause

Multiple local agents are sharing one OpenCode SQLite data store on the Paperclip host. When more than one `opencode` process writes to the same database, one run can fail with `database is locked`, which then surfaces as `adapter_failed` in Paperclip.

## Immediate recovery

Run these checks on the Paperclip host that owns the local agent processes:

```bash
pgrep -a opencode
ls -la ~/.local/share/opencode/
fuser ~/.local/share/opencode/opencode.db 2>/dev/null
```

If a stale `opencode` process is holding the database lock, terminate it and re-run the Prometheus heartbeat.

Also inspect the issue or run history for a second Prometheus run still marked `running`. Clear or reap the stale run before retrying so the next heartbeat is not confused by a zombie execution record.

## Recommended platform fix

Give each local agent its own OpenCode data directory instead of sharing the default SQLite path. For Prometheus, configure a dedicated `XDG_DATA_HOME`, for example:

```json
{
  "env": {
    "XDG_DATA_HOME": "/home/node/.paperclip/opencode-data/prometheus"
  }
}
```

Apply the same pattern to other local coding agents so they do not contend on the same SQLite database.

If per-agent data isolation cannot be rolled out immediately, serialize local `opencode` runs on the host as a short-term containment step.

## Control-plane blocker discovered in this heartbeat

This Cursor Cloud heartbeat can read Paperclip wake metadata, but it does not have a usable Paperclip bearer token exposed in the environment. Attempts to call the Paperclip API returned `401 Unauthorized`.

That means this heartbeat could not post a comment or patch issue status directly, even though the issue and run identifiers were available through `PAPERCLIP_WAKE_PAYLOAD_JSON`.

## Unblock owner and action

- **Owner:** Casius Nexus (CTO) / platform operations
- **Action 1:** Update the local Prometheus adapter config to use a dedicated `XDG_DATA_HOME`, then retry the failed heartbeat after clearing any stale `opencode` process or stuck `running` run record.
- **Action 2:** Restore Paperclip agent mutation auth for cloud heartbeats by ensuring the runtime exposes a valid agent bearer (API key or run JWT) to this execution path.

## Recommended issue disposition

Keep `GRA-77` in `blocked` until:

1. Prometheus is isolated from the shared OpenCode SQLite database or local runs are serialized, and
2. the control plane again exposes valid Paperclip mutation auth so heartbeat agents can update issue state directly.

Once both are fixed, the next heartbeat should:

1. confirm no stale Prometheus run is still marked `running`,
2. rerun the blocked recovery work, and
3. move the issue out of `blocked` only after the retry succeeds.
