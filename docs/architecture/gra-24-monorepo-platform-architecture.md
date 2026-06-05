# GRA-24: GrahmOS Monorepo Structure and Platform API Contracts

Status: Proposed for CTO review
Owner: Osiris Hermes (CEO)
Scope: Hermes, OpenClaw, Accio Source, JAM Media

## 1. Executive summary

GrahmOS should operate as a single monorepo with four brand-facing applications
on top of a shared platform layer. The monorepo must optimize for:

- one place to define shared contracts, auth, telemetry, and governance
- separate deployability for each brand and each platform service
- strict ownership boundaries so one brand can move quickly without breaking another
- generated SDKs and schemas so API drift is detected early

This document proposes a repo layout, ownership model, and a first-pass platform
API contract that all brands can consume consistently.

## 2. Architecture principles

1. Shared capabilities live once.
   - Auth, billing, analytics, assets, workflow execution, and contract definitions
     belong to the platform layer, not to individual brands.
2. Brands own experiences, not infrastructure primitives.
   - Hermes, OpenClaw, Accio Source, and JAM Media can ship distinct UX flows, but
     they should consume the same identity, workspace, billing, and event models.
3. Contracts are source-controlled artifacts.
   - OpenAPI, event schemas, and generated clients must live in the repo and version
     with code changes.
4. Frontends never call databases directly.
   - Brand applications call a brand BFF or shared platform API.
5. Every side effect is observable.
   - Trace IDs, idempotency keys, audit trails, and event envelopes are part of the
     contract rather than optional implementation details.

## 3. Proposed monorepo structure

Recommended workspace tooling: pnpm workspaces + Turborepo. If the runtime stack
changes later, preserve the same package and ownership boundaries.

```text
grahmos/
  apps/
    control-plane/           # Internal admin and company operations UI
    hermes-web/              # Hermes product surface
    openclaw-web/            # OpenClaw product surface
    accio-source-web/        # Accio Source product surface
    jam-media-web/           # JAM Media product surface
    docs/                    # Public docs and developer portal
  services/
    api-gateway/             # Edge routing, auth enforcement, rate limiting
    identity-service/        # Users, orgs, workspaces, roles, sessions
    project-service/         # Projects, environments, connectors, ownership
    workflow-service/        # Runs, jobs, tasks, agent orchestration
    content-service/         # Content items, publishing metadata, localization
    asset-service/           # File upload, asset lifecycle, media metadata
    billing-service/         # Plans, entitlements, subscriptions, invoices
    analytics-service/       # Product analytics, attribution, reporting
    notification-service/    # Email, webhook, in-product notification dispatch
  packages/
    contracts/               # OpenAPI, AsyncAPI, JSON Schema, shared types
    sdk-platform/            # Generated and hand-authored platform client SDK
    auth/                    # Auth helpers, session utilities, RBAC primitives
    ui/                      # Shared design system and component library
    brand-core/              # Shared branding hooks, feature flags, nav shells
    observability/           # Logging, metrics, tracing helpers
    config-eslint/
    config-typescript/
    config-vitest/
  infra/
    terraform/               # Cloud resources and shared environment modules
    ci/                      # CI/CD workflows, promotion rules, policy gates
  scripts/
    codegen/                 # Contract generation and lint automation
    repo/                    # Workspace bootstrap and maintenance scripts
  docs/
    architecture/
    adr/
```

## 4. Ownership boundaries

### Platform team ownership

The platform layer owns:

- services/*
- packages/contracts
- packages/sdk-platform
- packages/auth
- packages/observability
- infra/*

### Brand ownership

- Hermes team: apps/hermes-web and packages/hermes-* if needed
- OpenClaw team: apps/openclaw-web and packages/openclaw-* if needed
- Accio Source team: apps/accio-source-web and packages/accio-source-* if needed
- JAM Media team: apps/jam-media-web and packages/jam-media-* if needed

### Shared UI ownership

- packages/ui and packages/brand-core are co-owned by platform plus the current
  design authority. Brand-specific presentation overrides should live in each brand
  app rather than fragmenting the design system.

## 5. Deployment model

- Each app in apps/* deploys independently.
- Each service in services/* deploys independently behind the API gateway.
- packages/* are never deployed directly; they are versioned through the monorepo
  and consumed by apps and services.
- Shared migrations and infrastructure changes require contract review because they
  affect all brands.

## 6. Platform API contract rules

### Transport and versioning

- Synchronous APIs: HTTPS + JSON
- Asynchronous APIs: event bus or webhook delivery using the shared event envelope
- Base path: /v1
- Breaking changes require a new versioned namespace or opt-in capability flag

### Authentication and tenancy

- Bearer JWT access tokens issued by the identity service
- Every request carries tenantId and workspaceId in the token claims
- Cross-workspace access is denied by default
- Service-to-service calls use scoped machine credentials

### Required request headers

- Authorization: Bearer <token>
- X-Request-Id: caller-generated request correlation ID
- Idempotency-Key: required for POST requests with side effects
- X-Brand: hermes | openclaw | accio-source | jam-media

### Canonical response envelope

Successful list responses return:

```json
{
  "data": [],
  "page": {
    "nextCursor": null
  }
}
```

Successful single-resource responses return:

```json
{
  "data": {}
}
```

Errors follow RFC 7807 style problem details:

```json
{
  "type": "https://api.grahmos.dev/errors/conflict",
  "title": "Conflict",
  "status": 409,
  "code": "resource_conflict",
  "detail": "A project with this slug already exists.",
  "traceId": "trc_123"
}
```

## 7. Shared domain model

The following entities are shared across every brand:

- Tenant: top-level customer or company account
- Workspace: isolated environment under a tenant
- User: authenticated actor
- Membership: user role within a tenant or workspace
- Brand: Hermes, OpenClaw, Accio Source, or JAM Media
- Project: unit of customer work, content, automation, or configuration
- Run: execution record for automation, jobs, or agent workflows
- Asset: uploaded file or media artifact
- ContentItem: publishable unit used by content-heavy brands
- Subscription: plan and entitlement record
- Event: immutable activity record emitted by services

## 8. Brand-to-platform consumption matrix

| Capability | Hermes | OpenClaw | Accio Source | JAM Media |
|---|---|---|---|---|
| Identity and RBAC | Required | Required | Required | Required |
| Workspaces and projects | Required | Required | Required | Required |
| Workflow execution | Required | Required | Optional | Optional |
| Content items | Optional | Optional | Required | Required |
| Asset management | Required | Required | Required | Required |
| Billing and entitlements | Required | Required | Required | Required |
| Analytics and attribution | Required | Required | Required | Required |
| Notifications and webhooks | Required | Required | Required | Required |

## 9. First-pass platform API surface

### Identity and tenancy

- POST /v1/tenants
- GET /v1/tenants/{tenantId}
- POST /v1/workspaces
- GET /v1/workspaces/{workspaceId}
- POST /v1/memberships

### Brand registry and capability discovery

- GET /v1/brands
- GET /v1/brands/{brandId}
- GET /v1/brands/{brandId}/capabilities

### Projects and environments

- POST /v1/projects
- GET /v1/projects/{projectId}
- PATCH /v1/projects/{projectId}
- GET /v1/projects

### Workflow execution

- POST /v1/runs
- GET /v1/runs/{runId}
- GET /v1/runs
- POST /v1/runs/{runId}/cancel

### Content and assets

- POST /v1/content-items
- GET /v1/content-items/{contentItemId}
- PATCH /v1/content-items/{contentItemId}
- POST /v1/assets
- GET /v1/assets/{assetId}

### Billing and analytics

- GET /v1/subscriptions
- POST /v1/subscriptions
- GET /v1/analytics/summary

## 10. Shared asynchronous event contract

All services emit the same envelope:

```json
{
  "eventId": "evt_123",
  "eventType": "run.created",
  "eventVersion": 1,
  "occurredAt": "2026-06-05T21:00:00Z",
  "tenantId": "ten_123",
  "workspaceId": "wks_123",
  "brandId": "hermes",
  "traceId": "trc_123",
  "payload": {}
}
```

Required first-wave event families:

- tenant.created
- workspace.created
- project.created
- project.updated
- run.created
- run.completed
- run.failed
- content-item.published
- asset.created
- subscription.updated

## 11. Repo governance rules

- Contract changes in packages/contracts require review from the platform owner.
- Brand apps may add brand-local BFF endpoints, but shared service contracts must
  stay in the common spec.
- Generated SDK output must be reproducible in CI.
- No app may import from another app; shared logic must move into packages/*.
- Service ownership, on-call, and escalation paths should be captured in CODEOWNERS
  once the engineering org is ready to enforce them.

## 12. Recommended implementation order

1. Stand up the monorepo workspace and CI skeleton.
2. Land packages/contracts with OpenAPI and event schema definitions.
3. Implement identity-service, project-service, and api-gateway first because every
   brand depends on them.
4. Add workflow-service and asset-service next for Hermes and OpenClaw.
5. Add content-service for Accio Source and JAM Media.
6. Finish billing-service, analytics-service, and notification-service.

## 13. Decisions required from the CTO

The architecture above is concrete enough to unblock repo setup, but three
engineering decisions still need CTO approval before implementation starts:

1. Runtime baseline
   - Confirm the primary server framework and deployment target for services.
2. Data plane
   - Confirm whether the shared platform will align on one primary OLTP store plus
     one analytics store, or split by service from day one.
3. Auth provider
   - Confirm whether identity-service wraps a third-party IdP or owns first-party
     credential flows.

## 14. Exit criteria for GRA-24

This issue can be considered complete when:

- the repo accepts this structure as the target architecture
- the platform OpenAPI contract becomes the canonical shared interface
- follow-on implementation work is split into service and workspace setup issues
