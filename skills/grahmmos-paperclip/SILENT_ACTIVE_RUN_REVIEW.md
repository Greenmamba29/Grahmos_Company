# Silent Active Run Review Playbook

Use this playbook when a Paperclip issue reports that a local Hermes-backed
agent appears **active** but is not producing visible work, comments, or logs.
This is the expected first response path for incidents like:

- `GRA-110 Review silent active run for Casius Nexus`

## Scope

This applies to GrahmOS agents that use the **Hermes Agent (local)** adapter,
including Casius Nexus (CTO) and the other local executive or specialist agents.

## Symptoms

Treat the run as "silent active" when one or more of the following are true:

- The agent run is marked active in Paperclip.
- There is no meaningful terminal or issue-thread output.
- No child issues, comments, or durable artifacts are produced.
- The run remains active across multiple heartbeat opportunities without
  observable progress.

## Most Likely Causes

1. The `hermes` binary is not available in the Paperclip container.
2. The configured working directory does not exist or is not a valid repo.
3. The Paperclip-managed `AGENTS.md` bundle is missing.
4. The adapter can start, but the workspace checkout failed before execution.
5. The run is waiting on an external dependency while the issue state was left
   as active instead of blocked.

## Review Checklist

### 1. Confirm the agent configuration

Verify all of the following in Paperclip:

- Adapter type is `Hermes Agent (local)`.
- Working directory points to the expected workspace.
- The intended repository is available in that workspace.
- The managed instructions bundle exists for the assigned agent.

### 2. Check the runtime prerequisites

From the runtime/container that hosts the local agent, verify:

- `hermes` is installed and on `PATH`.
- The workspace directory exists.
- The repository has been cloned successfully.
- The configured starting ref or branch exists.

### 3. Classify the failure correctly

Use the first missing prerequisite to classify the incident:

- Missing `hermes` binary -> **platform/infrastructure blocker**
- Missing workspace or repo checkout -> **workspace/bootstrap blocker**
- Missing managed instructions bundle -> **agent configuration blocker**
- External system dependency with no execution path -> **dependency blocker**

Do **not** leave the issue `in_progress` if the run cannot execute useful work.

### 4. Leave durable progress

Every review should produce at least one durable artifact:

- issue comment with findings,
- issue status update,
- child issue delegated to the unblock owner, or
- repository documentation/runbook update when the failure mode was unclear.

### 5. Choose the final disposition

- Mark `done` only if the run was reviewed and no remaining action is required.
- Mark `in_review` only when a real reviewer or approver must respond.
- Mark `blocked` when there is a named unblock owner and next action.
- Keep `in_progress` only when there is a live continuation path already in
  motion, not just a note saying "remaining".

## Recommended Blocker Ownership

Use these defaults unless the incident shows a more specific owner:

- Local adapter or container setup -> Platform / infrastructure owner
- Missing Paperclip instructions bundle -> Paperclip admin / company operator
- Invalid repo/workspace configuration -> Repo or adapter owner
- Agent task ambiguity -> Assignee or delegating executive

## GrahmOS-Specific Notes

- Casius Nexus is configured as the CTO and uses the Hermes local adapter.
- The existing GrahmOS setup docs already track these known failure modes:
  - missing `AGENTS.md` bundle,
  - missing repository URL or default branch,
  - failed `hermes` startup due to an uninitialized workspace.

If a future silent active run occurs, update this playbook with the exact root
cause and the command or config change that resolved it.
