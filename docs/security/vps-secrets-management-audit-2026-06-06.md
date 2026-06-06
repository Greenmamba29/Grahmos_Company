# GrahmOS VPS Secrets Management Audit - 2026-06-06

## Summary

This audit reviews the current GrahmOS repository evidence and the active Cursor
Cloud runtime for secret handling gaps related to GRA-31.

Overall result: **partially compliant, with one high-priority operational gap**.

## Method

The audit used only evidence available in this heartbeat:

- tracked files in the current repository checkout
- the current injected runtime environment
- the company setup skill in `skills/grahmmos-paperclip/SKILL.md`
- targeted searches for Docker assets and likely committed live credentials

## Evidence observed

### Repository evidence

- The repo contains documentation and agent setup artifacts, but no Dockerfiles
  or Compose manifests were present in the current checkout.
- Targeted secret-pattern scans found no likely live credentials committed to
  tracked files.
- The company skill documents some required environment variables, including
  `CURSOR_API_KEY` and `GH_TOKEN`.

### Runtime evidence

- The current shell includes injected Paperclip metadata variables such as
  `PAPERCLIP_API_URL`, `PAPERCLIP_AGENT_ID`, `PAPERCLIP_COMPANY_ID`, and
  related wake metadata.
- The injected secret name list does **not** include `PAPERCLIP_API_KEY`.
- `GET /api/auth/get-session` returns `401 {"error":"Board authentication required"}`.
- `GET /api/companies/{companyId}/issues?identifier=GRA-31` returns
  `401 {"error":"Unauthorized"}`.

These results show that the deployment currently distinguishes between metadata
and mutable board credentials, but the runtime still lacks the secret needed to
perform authenticated Paperclip issue operations.

## Findings

### Finding 1 - Missing Paperclip agent credential in the cloud runtime

- Severity: **high**
- Status: **open**
- Owner: Paperclip operator

The current cloud shell cannot mutate or read private company issues because
`PAPERCLIP_API_KEY` is not injected into the agent environment.

Risk:

- blocked issue updates and recovery actions
- inability to leave final dispositions directly in the system of record
- slower incident response when authenticated issue access is required

Required action:

- inject `PAPERCLIP_API_KEY` into the Cursor Cloud adapter environment for this
  agent
- verify authenticated access on the next heartbeat

### Finding 2 - Secret inventory is documented incompletely

- Severity: **medium**
- Status: **mitigated by policy added in this heartbeat**
- Owner: platform operator

The repository previously documented some required secrets, but it did not
provide a single rotation policy spanning Cursor, GitHub, Paperclip, and other
operator-managed credentials.

Risk:

- inconsistent rotation cadence
- inconsistent evidence after rotations
- missed revocation during personnel or environment changes

Mitigation delivered:

- `docs/security/api-key-rotation-policy.md`

### Finding 3 - Docker hardening could not be verified from repo state

- Severity: **medium**
- Status: **open**
- Owner: VPS operator / infrastructure lead

No Docker deployment artifacts were available in this checkout, so the live VPS
container posture could not be verified directly from code.

Risk:

- production containers may drift from baseline without reviewable evidence
- privileged or mutable container settings may go unnoticed

Mitigation delivered:

- `docs/security/docker-security-hardening.md`

Required follow-up:

- compare the live VPS Docker or Compose configuration against the documented
  baseline
- record exceptions explicitly

## Controls confirmed during this audit

- no likely live secrets were found in tracked repo files from the targeted scan
- the runtime uses injected environment variables rather than hard-coded repo
  values for the Paperclip metadata it does expose

## Recommended next actions

1. Inject `PAPERCLIP_API_KEY` into the Cursor Cloud adapter environment.
2. Verify authenticated Paperclip access from a resumed heartbeat.
3. Review the live VPS Docker or Compose configuration against the new
   hardening baseline.
4. Record the current secret inventory and next rotation dates using the new
   policy.

## Exit criteria for closing GRA-31

GRA-31 can be treated as fully complete when all of the following are true:

- the API key rotation policy is accepted as the source of truth
- the live VPS deployment has been checked against the Docker hardening
  baseline
- the missing `PAPERCLIP_API_KEY` injection gap is fixed or formally waived
- the resulting verification evidence is attached to the issue or deployment
  record
