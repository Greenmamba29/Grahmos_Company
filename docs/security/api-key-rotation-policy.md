# GrahmOS API Key Rotation Policy

## Purpose

This policy defines how GrahmOS provisions, rotates, revokes, and verifies
high-privilege credentials used across Cursor Cloud, Paperclip, GitHub, and
other operator-managed services.

## Scope

This policy applies to:

- `CURSOR_API_KEY`
- `GH_TOKEN`
- `PAPERCLIP_API_KEY`
- `OPENCODE_API_KEY`
- Telegram bot tokens and other operator-managed service credentials
- any future vendor API key that can mutate company systems, read private data,
  or impersonate an agent or operator

## Credential classes

### Tier 0 - platform control

Examples:

- `GH_TOKEN`
- `PAPERCLIP_API_KEY`
- Telegram bot token

Impact:

- can change production state, mutate issue records, or exfiltrate private
  operational data

### Tier 1 - agent execution

Examples:

- `CURSOR_API_KEY`
- `OPENCODE_API_KEY`

Impact:

- can execute background work, trigger model usage, or access internal
  automation surfaces

### Tier 2 - low-risk service access

Examples:

- read-only vendor integrations or scoped monitoring keys

Impact:

- limited blast radius and no governance-changing access

## Rotation cadence

| Class | Default cadence | Maximum age | Notes |
| --- | --- | --- | --- |
| Tier 0 | every 30 days | 45 days | rotate immediately after any suspected exposure |
| Tier 1 | every 45 days | 60 days | shorten cadence for broadly shared automation keys |
| Tier 2 | every 90 days | 120 days | maintain provider minimum scope |

## Immediate rotation triggers

Rotate the affected credential immediately when any of the following occurs:

- an agent, operator, or contractor loses access or changes role
- a secret appears in logs, screenshots, prompts, or git history
- a deployment host or workstation is suspected compromised
- the provider reports a security incident
- permissions on the credential are expanded
- an audit cannot confirm where the current value is stored or who can read it

## Source-of-truth rules

1. Never commit live secrets to git.
2. Store production secrets only in the approved secret manager or adapter-level
   secret reference system.
3. Use distinct credentials per environment and per major platform when
   possible.
4. Prefer short-lived or individually attributable credentials over shared
   long-lived tokens.
5. Name secrets consistently so rotation evidence can be matched back to the
   system using them.

## Rotation procedure

### 1. Prepare

- identify every system that reads the credential
- confirm the owner of the credential and fallback operator
- create the replacement credential with least privilege
- set an overlap window only as long as needed for cutover

### 2. Cut over

- update the secret in the central secret store or adapter config
- redeploy or restart only the consumers that require the new value
- avoid keeping both old and new values active longer than necessary

### 3. Verify

- confirm the dependent workflow succeeds with the new credential
- confirm audit or runtime tooling shows the new secret is injected
- confirm no callers still depend on the previous value

### 4. Revoke

- revoke the old credential at the provider
- remove any stale local copies, shell exports, scratch files, or screenshots
- record the completion evidence

## Minimum evidence for each rotation

Each completed rotation must leave durable evidence containing:

- credential name
- owner
- reason for rotation
- systems updated
- verification result
- revocation confirmation for the previous credential
- date of next scheduled rotation

Do not treat a new secret value by itself as proof of completion.

## Emergency rotation workflow

For a suspected leak:

1. revoke or disable the exposed credential first if the system can tolerate it
2. create the replacement credential
3. redeploy the affected services
4. review logs, prompts, and commits for secondary exposure
5. document incident scope and follow-up actions

## GrahmOS minimum current-state requirements

The following controls are required across GrahmOS-managed credentials:

- all Tier 0 and Tier 1 secrets must be injected from a secrets system, not
  hard-coded in repo files
- each active agent runtime must have only the secrets it actually needs
- missing credentials that block issue mutation or governance workflows must be
  treated as operational risk, not only as convenience bugs
- secret inventory must be reviewed during every infrastructure or adapter audit

## Review cadence

- review this policy during any platform onboarding change
- review credential inventory monthly
- run a focused exception review after every incident involving credentials
