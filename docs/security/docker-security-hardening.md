# GrahmOS Docker Security Hardening Baseline

## Purpose

This baseline defines the minimum container security controls for GrahmOS
services deployed on a VPS or other operator-managed host.

This repository does not currently contain Dockerfiles or Compose manifests, so
this document serves as the required hardening baseline for the separate
deployment surface.

## Baseline controls

### 1. Run as non-root

- set an explicit non-root `USER` in each image
- avoid runtime flags that escalate to root unless a documented exception exists
- ensure mounted directories are writable by the service account rather than by
  granting root access

### 2. Minimize image contents

- use small base images
- pin image versions by digest where practical
- remove build tools from runtime layers
- keep only the binaries and certificates required for execution

### 3. Drop privilege by default

- use `cap_drop: ["ALL"]`
- add back only narrowly required Linux capabilities
- never run production services with `--privileged`
- avoid host PID, host IPC, and host network modes unless formally approved

### 4. Use a read-only filesystem where possible

- set `read_only: true` for services that do not need persistent writes
- provide `tmpfs` mounts for ephemeral runtime data
- mount persistent writable paths explicitly rather than leaving the whole
  filesystem mutable

### 5. Restrict secrets exposure

- inject secrets from a secret store or controlled environment manager
- prefer file mounts under `/run/secrets` or narrowly scoped environment
  injection over baking secrets into images
- never copy live secrets into the image at build time
- redact secrets from startup logs and healthcheck output

### 6. Constrain networking

- expose only required ports
- bind internal services to private networks when internet exposure is not
  needed
- separate public ingress containers from internal-only services
- document every egress dependency for high-privilege services

### 7. Set resource limits

- define CPU and memory limits
- define restart policy intentionally
- use healthchecks for failure detection instead of relying on operator memory
- keep log rotation enabled to avoid disk exhaustion

### 8. Harden the host interface

- keep the Docker engine and host kernel patched
- restrict membership in the `docker` group
- protect the Docker socket from application containers
- disable unused exposed daemon endpoints

### 9. Scan and patch regularly

- scan images before deployment
- rebuild images after upstream security advisories affecting the base image
- rotate or rebuild immediately after a credential exposure event

## Deployment review checklist

Before a new service reaches production, confirm:

- image runs as non-root
- image source and version are pinned
- root filesystem mutability is justified
- privileges and capabilities are minimized
- secrets are injected externally
- no unnecessary public ports are exposed
- resource limits and healthchecks are configured
- container logs do not print secrets or bearer tokens

## Example Compose baseline

```yaml
services:
  app:
    image: ghcr.io/example/app@sha256:replace-me
    user: "10001:10001"
    read_only: true
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped
    environment:
      APP_ENV: production
    env_file:
      - /etc/grahmos/app.env
    ports:
      - "127.0.0.1:8080:8080"
```

## Exception process

Any service that cannot satisfy the baseline must document:

- the exact control being waived
- why the service requires the exception
- the blast radius if the exception is abused
- compensating controls
- owner and review date

An undocumented exception should be treated as a failed security review.
