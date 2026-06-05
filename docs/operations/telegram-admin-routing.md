# GrahmOS Telegram Admin Routing

This document defines how GrahmOS should route administrative and incident
notifications across its 15 planned agent seats. The machine-readable source of
truth lives in `config/telegram-admin-routing.json`.

## Goals

- Give every agent seat a deterministic admin route.
- Separate leadership, platform, product, and GTM escalations.
- Make blocked issues and incidents visible without relying on ad hoc DMs.
- Keep unknown seats explicit instead of silently omitting them from routing.

## Route groups

| Route group | Purpose | Default owner |
| --- | --- | --- |
| `leadership` | Governance, board, and cross-company blockers | Osiris Hermes |
| `product-revenue` | Product scope, GTM execution, revenue follow-through | Athena / Midas |
| `creative-growth` | Content, design, campaign, and growth work | Apollo / Echo / Daedalus |
| `engineering` | Application and AI implementation tasks | Casius Nexus / Lyra / Minerva |
| `platform` | Infra, runtime, deployments, and reliability | Prometheus |
| `operator-on-call` | Fallback for missing ownership or environment problems | Paperclip operator |

## Routing principles

1. Every seat belongs to exactly one primary route group.
2. Every seat has a named fallback escalation path.
3. Leadership and operator routes remain the last-resort path for unresolved or
   cross-functional blockers.
4. Reserved seats stay in the config so the system reaches 15 routable slots
   before the final roster is known.

## Activation checklist

Before enabling live Telegram delivery:

1. Replace placeholder `chatId` values with real Telegram chat IDs.
2. Replace placeholder `threadId` values with real topic/thread IDs.
3. Inject the Telegram bot token through secrets management, not through git.
4. Confirm the final names for seats 12-15.
5. Validate the config:

   ```bash
   python3 scripts/validate-telegram-routing.py
   ```

6. Send a smoke-test alert to each route group.

## Current state

The repository now captures:

- the confirmed named seats from the GrahmOS skill
- one additional observed seat (`Minerva`) from live issue execution history
- four reserved seats so the config reaches the requested 15-agent footprint

The repository still does not capture:

- real Telegram secrets
- real chat IDs
- real thread IDs
- board-confirmed identities for the final four seats

That means the routing config is structurally ready but not yet production-live.
