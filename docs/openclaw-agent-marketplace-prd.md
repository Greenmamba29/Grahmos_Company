# OpenClaw Agent Marketplace PRD

Status: Draft v1
Owner: Osiris Hermes (CEO)
Product: OpenClaw
Related doc: [GrahmOS Product Roadmap v1](./grahmos-product-roadmap-v1.md)

## 1. Product summary

OpenClaw is the discovery and distribution layer for the GrahmOS ecosystem. Its
first product goal is to help buyers find trusted AI agents and help builders
present those agents in a high-quality, reviewable format.

The v1 marketplace should optimize for trust, clarity, and qualified demand
rather than for maximum catalog size.

## 2. Problem

Teams evaluating AI agents face three recurring problems:

1. **Discovery is noisy.** There is no trusted place to compare production-ready
   agents with consistent metadata.
2. **Quality is opaque.** Buyers cannot easily understand what an agent does,
   what systems it touches, or how mature it is.
3. **Deployment intent is lost.** Even when interest exists, handoff into the
   next workflow is unclear and difficult to measure.

Builders face a parallel problem: they lack a credible environment to present
agents with the level of structure enterprise buyers expect.

## 3. Vision

OpenClaw becomes the default marketplace for trustworthy AI agents by combining:

- Curated supply
- Rich technical metadata
- Clear deployment pathways
- Governance and trust signals

## 4. Goals

### Primary goals

- Let buyers discover relevant agents by use case, category, and maturity
- Let builders submit agents through a structured intake flow
- Present every approved listing with enough information to support evaluation
- Capture and route deployment intent into the next GrahmOS workflow

### Non-goals for v1

- Fully open self-serve publishing with no review gate
- Complex in-product billing or revenue settlement
- Real-time chat, forums, or community features
- Deep post-deployment lifecycle management inside OpenClaw itself

## 5. Target users

### Buyer persona: Operator

An operations, product, or platform lead evaluating agents for a team or
workflow. They care about trust, implementation effort, and business value.

### Builder persona: Agent creator

A team or independent builder with an agent worth distributing. They want
exposure, credible presentation, and a path to qualified demand.

### Internal persona: GrahmOS reviewer

An operator responsible for reviewing submissions, curating listings, and
maintaining marketplace quality.

## 6. User stories

- As a buyer, I want to browse by category so I can quickly narrow the market.
- As a buyer, I want to understand integrations, inputs, outputs, and maturity
  so I can judge fitness for deployment.
- As a buyer, I want a clear next step to request access, a demo, or deployment
  guidance.
- As a builder, I want a structured submission flow so my agent can be reviewed
  consistently.
- As a reviewer, I want approval controls so the marketplace remains high trust.

## 7. v1 scope

### In scope

1. Marketplace home and category navigation
2. Search and filter for listings
3. Agent detail pages
4. Structured submission flow for new agents
5. Internal review and approval workflow
6. Trust metadata on listings
7. Deployment intent capture flow
8. Basic analytics for traffic, submission, approval, and intent conversion

### Out of scope

1. Automated payouts to builders
2. Public user reviews and rating systems
3. Instant deployment into every target environment
4. Marketplace APIs for third-party syndication

## 8. Functional requirements

### FR-1 Listing model

Each agent listing must support:

- Name
- Short value proposition
- Long description
- Category and use case tags
- Builder identity
- Supported integrations
- Input and output description
- Maturity level (experimental, beta, production-ready)
- Deployment model
- Support level
- Trust signals (reviewed, verified, internal recommended, etc.)

### FR-2 Discovery

Users must be able to:

- Browse categories
- Search by keyword
- Filter by category, maturity, deployment model, and trust status
- Sort by featured or recent

### FR-3 Agent detail page

Every approved listing must have a detail page containing:

- Core overview
- Capability summary
- Integration requirements
- Maturity and support details
- Trust and review status
- Primary call to action for deployment intent

### FR-4 Submission workflow

Builders must be able to submit a listing through a structured form with the
fields required by FR-1 plus:

- Contact information
- Demo or documentation links
- Evidence of production usage or testing, if available

Submissions should remain unpublished until approved.

### FR-5 Review workflow

Internal reviewers must be able to:

- View pending submissions
- Mark submissions approved, rejected, or needs changes
- Attach reviewer notes
- Control featured status and trust labels

### FR-6 Deployment intent capture

Each listing must expose a clear next step such as:

- Request demo
- Request deployment guidance
- Request access

The system must capture the selected intent and route it into a follow-up queue
or CRM-compatible workflow.

### FR-7 Analytics

The product must record:

- Listing views
- Search usage
- Submission volume
- Approval rate
- Intent conversion by listing and category

## 9. Experience requirements

- The marketplace should feel curated rather than crowded.
- Listing pages should prioritize scannability and confidence.
- Trust labels should be meaningful and sparingly used.
- Calls to action should be explicit and low-friction.

## 10. Success metrics

### Supply metrics

- Number of approved listings
- Approval rate from submitted to published
- Percentage of listings with complete metadata

### Demand metrics

- Unique visitors to listing pages
- Search-to-detail-page click-through rate
- Detail-page-to-intent conversion rate

### Quality metrics

- Percentage of listings with trust review completed
- Percentage of intent submissions routed successfully
- Time from submission to review decision

## 11. Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Low-quality submissions flood the system | Trust drops early | Keep curation and review mandatory in v1 |
| Sparse metadata makes listings look shallow | Conversion falls | Require structured fields and completeness checks |
| No clear post-click workflow | Interest does not become pipeline | Instrument intent capture and route it reliably |
| Too many trust labels | Buyers stop believing them | Limit labels to a small, governed set |

## 12. Open questions

1. Which deployment intents should be supported at launch: demo, access,
   deployment, or all three?
2. Should the first release support only curated internal listings, or also
   selected external builders?
3. What system will own the post-intent follow-up queue?
4. Which trust labels can be backed by auditable review criteria in v1?

## 13. Launch checklist

- Define the canonical listing schema
- Design the submission and review interfaces
- Implement analytics for discovery and intent capture
- Create the initial curated catalog
- Write reviewer policy for trust labels and approvals
- Connect post-intent routing to the chosen follow-up workflow
