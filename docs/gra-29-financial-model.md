# GRA-29 Financial Model, Pricing Tiers, and Accio Revenue Projections

## Status

Draft v0.1 for internal planning and board review. This is an operator-ready model
framework with explicit assumptions, recommended pricing, and scenario-based Accio
revenue projections. It is designed to unblock go-to-market, budget, and hiring
decisions even before live customer data exists.

## Executive Summary

- Use a three-tier GrahmOS pricing model to balance fast entry, healthy gross
  margin, and a credible enterprise upsell path.
- Position Accio as the most accessible revenue engine in the portfolio, with a
  lower entry price than custom infrastructure work and clear expansion levers.
- Plan around three operating scenarios for Accio:
  - Conservative: validate willingness to pay and repeatability.
  - Base: achieve a repeatable SMB and agency motion.
  - Aggressive: combine founder-led sales with outbound and partner leverage.
- Treat implementation fees and usage overages as upside rather than the base
  business case.

## Modeling Assumptions

### Core company assumptions

| Assumption | Value | Notes |
| --- | --- | --- |
| Gross margin target | 75%+ blended | AI and infra costs require pricing discipline. |
| Billing cadence | Monthly default, annual for enterprise | Annual plans improve cash flow. |
| Services mix | 10% to 20% of total revenue | Helpful for onboarding, but not the main business. |
| Sales motion | Founder-led initially | Move to repeatable operator motion after validation. |
| Pricing review cadence | Quarterly | Update after first 5 to 10 paying customers. |

### Unit economics guardrails

| Metric | Target | Why it matters |
| --- | --- | --- |
| Gross margin per account | 70% minimum | Protects headroom for support and growth. |
| Payback period | < 6 months | Important while sales is still founder-led. |
| Net revenue retention | 110%+ | Expansion revenue should eventually outpace churn. |
| Churn | < 3% monthly for SMB, < 10% annual for enterprise | Required for predictable compounding. |

## Recommended GrahmOS Pricing Tiers

These tiers can anchor company-wide pricing conversations even if the product mix
varies by brand. They intentionally separate recurring platform value from setup
or custom work.

| Tier | Target customer | Monthly price | Annual equivalent | Included value | Expansion levers |
| --- | --- | ---: | ---: | --- | --- |
| Launch | Solo builders, small teams, early pilots | $499 | $4,990 | Core workspace, limited automation volume, async support | Seat add-ons, usage overages |
| Growth | SMBs, agencies, internal ops teams | $1,499 | $14,990 | Higher automation limits, priority support, shared team workflows | Additional seats, premium workflows, onboarding |
| Enterprise | Mid-market and strategic accounts | $4,500+ | $54,000+ | Security review support, custom onboarding, SLAs, governance controls | Annual commitments, implementation, premium support |

### Pricing principles

1. **Do not underprice the Growth tier.** It should be the primary monetization
   band, not a discounted transition plan.
2. **Keep Launch self-serve or near self-serve.** If it needs custom onboarding,
   margins collapse.
3. **Reserve discounts for annual prepay or multi-product bundles.**
4. **Separate platform revenue from services revenue.** Customers should always
   understand what is recurring and what is one-time.

## Accio Recommended Packaging

Accio should lead with simpler packaging than the broader GrahmOS platform. The
goal is fast conversion, clear ROI, and easy expansion into Growth and Agency
accounts.

| Tier | Target buyer | Monthly price | Annual equivalent | Included value |
| --- | --- | ---: | ---: | --- |
| Team | Small recruiting, research, or sourcing teams | $399 | $3,990 | Core search workflows, email support, moderate usage allowance |
| Growth | Agencies and internal revenue teams | $999 | $9,990 | Higher usage, collaboration, saved workflows, priority support |
| Agency / Pro | Multi-client operators and heavier users | $2,499 | $24,990 | Multi-workspace support, higher usage, white-glove onboarding |
| Enterprise | Strategic accounts | Custom, starting at $5,000 | $60,000+ | Governance, SLA, custom data workflows, procurement support |

### Accio one-time revenue

| Item | Suggested price |
| --- | ---: |
| Onboarding / implementation | $1,500 to $5,000 |
| Custom workflow setup | $750 to $2,500 |
| Premium training | $500 to $2,000 |

## Financial Model Structure

Model revenue in four layers:

1. **Recurring subscription revenue**
2. **Usage overage revenue**
3. **Implementation and onboarding revenue**
4. **Expansion revenue from upgrades and additional seats**

### Formula references

- `MRR = sum(customers_by_tier * tier_price)`
- `ARR = MRR * 12`
- `Implementation Revenue = new_customers * average_setup_fee`
- `Blended Revenue = ARR + implementation_revenue + overages`
- `Gross Profit = Blended Revenue * gross_margin`

## Accio Scenario Assumptions

The scenario model below uses the Accio packaging above and keeps implementation
revenue modest. Each scenario assumes churn exists, but the topline is driven by
net growth after churn.

| Scenario | Avg Team customers | Avg Growth customers | Avg Agency / Pro customers | Avg setup fee | Expected sales motion |
| --- | ---: | ---: | ---: | ---: | --- |
| Conservative | 8 | 3 | 1 | $1,500 | Founder-led, mostly warm inbound |
| Base | 18 | 7 | 2 | $2,000 | Founder-led plus light outbound |
| Aggressive | 35 | 14 | 5 | $2,500 | Repeatable outbound, partnerships, stronger content engine |

## Accio Revenue Projection Summary

### Steady-state annualized scenario view

| Scenario | Subscription MRR | Subscription ARR | Estimated annual setup revenue | Total projected annual revenue |
| --- | ---: | ---: | ---: | ---: |
| Conservative | $8,688 | $104,256 | $18,000 | $122,256 |
| Base | $19,173 | $230,076 | $48,000 | $278,076 |
| Aggressive | $40,446 | $485,352 | $105,000 | $590,352 |

### How the scenario math works

- Conservative:
  - `(8 * $399) + (3 * $999) + (1 * $2,499) = $8,688 MRR`
- Base:
  - `(18 * $399) + (7 * $999) + (2 * $2,499) = $19,173 MRR`
- Aggressive:
  - `(35 * $399) + (14 * $999) + (5 * $2,499) = $40,446 MRR`

This scenario table is intentionally conservative about expansion revenue. Any
meaningful seat growth, premium support, or usage overage should be treated as
upside rather than required for the model to work.

## Base Scenario Monthly Ramp

This ramp is the clearest operating target for the next planning cycle.

| Month | Team customers | Growth customers | Agency / Pro customers | Projected MRR |
| --- | ---: | ---: | ---: | ---: |
| 1 | 3 | 1 | 0 | $2,196 |
| 2 | 5 | 2 | 0 | $3,993 |
| 3 | 7 | 2 | 1 | $7,290 |
| 4 | 9 | 3 | 1 | $9,087 |
| 5 | 11 | 4 | 1 | $10,884 |
| 6 | 13 | 5 | 1 | $12,681 |
| 7 | 15 | 5 | 2 | $15,978 |
| 8 | 17 | 6 | 2 | $17,775 |
| 9 | 19 | 7 | 2 | $19,572 |
| 10 | 21 | 8 | 2 | $21,369 |
| 11 | 23 | 9 | 2 | $23,166 |
| 12 | 25 | 10 | 3 | $27,462 |

### Base scenario interpretation

- The monthly ramp above produces about `$171,453` in first-year subscription
  revenue before setup fees.
- If the base scenario also lands roughly `$48,000` in setup revenue, the
  first-year topline is about `$219,453`.
- By month 12, the modeled exit MRR is `$27,462`, which implies an exit ARR of
  `$329,544` before any additional expansion revenue.
- Hitting month-12 MRR matters more than maximizing short-term implementation
  revenue.
- A team that can consistently close Growth tier accounts will likely justify a
  dedicated operator or sales hire before it justifies heavy engineering spend.

## Suggested Decision Gates

### Gate 1: Pricing validation

Trigger once the team has 5 paying accounts or 20 serious pricing conversations.

Questions:
- Is `$399` low enough to reduce friction but high enough to preserve margin?
- Are Growth accounts upgrading because of real usage ceilings or because Team is
  underpowered?
- Are onboarding fees accepted without heavy discounting?

### Gate 2: Sales repeatability

Trigger once there is a 90-day cohort to inspect.

Questions:
- Which channel closes Growth tier accounts fastest?
- What is the time-to-value from signed deal to active usage?
- What percentage of accounts add seats, overages, or implementation?

### Gate 3: Enterprise readiness

Trigger only after consistent Growth tier demand.

Questions:
- Are enterprise prospects asking for governance and security often enough to
  justify roadmap work?
- Is annual procurement demand real or only aspirational?
- Which enterprise requests can be sold now as premium service rather than core
  product work?

## Risks and Failure Modes

1. **Too many low-price customers with high-touch onboarding**
   - Fix: keep Launch and Team onboarding constrained and documented.
2. **Custom work masking weak product-market fit**
   - Fix: track recurring revenue separately from project revenue.
3. **Enterprise discounting too early**
   - Fix: trade discounts only for annual prepay, references, or strategic logos.
4. **No clear upgrade path**
   - Fix: define usage caps and collaboration features that make Growth obviously
     better than Team.

## Immediate Next Actions

1. Review whether the proposed Team / Growth / Agency pricing matches live buyer
   conversations.
2. Decide whether setup fees should be mandatory or optional for lower tiers.
3. Translate this markdown model into a spreadsheet with editable assumptions and
   monthly sensitivity tabs.
4. Use the base scenario as the operating plan and treat the conservative and
   aggressive cases as budget bounds.
