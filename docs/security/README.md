# GrahmOS Security Operations Pack

This directory captures the current GrahmOS security baseline for credential
rotation, container hardening, and VPS secret handling.

## Documents

- [API key rotation policy](api-key-rotation-policy.md)
- [Docker security hardening baseline](docker-security-hardening.md)
- [VPS secrets management audit - 2026-06-06](vps-secrets-management-audit-2026-06-06.md)

## Intended use

Use this pack when:

- onboarding or rotating high-privilege service credentials
- deploying or reviewing Docker-based workloads on the GrahmOS VPS
- auditing how secrets are stored, injected, rotated, and revoked

These documents are written to leave a durable baseline even when the live
Paperclip board or deployment host is not directly reachable from the current
cloud shell.
