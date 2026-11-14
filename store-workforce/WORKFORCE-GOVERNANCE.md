# Workforce Governance and Safety Rules

## Identity and access
- Every worker has a stable identifier and a service identity.
- Use least-privilege, task-scoped permissions; no shared administrator credentials.
- Secrets are stored in the approved secrets service and are never written into prompts, logs, or repository files.
- Customer data is accessed only when necessary for the assigned task.

## Execution lifecycle
`registered -> configured -> tested -> approved_for_pilot -> pilot -> production_enabled -> paused/retired`

The current registry state is `registered_not_deployed`. Do not represent a worker as active until runtime health checks and deployment records confirm it.

## Required audit trail
Record task identifier, worker identifier, model and version, prompt/configuration version, tool calls, input references, output references, start/end timestamps, approval identity, and final status. Avoid storing unnecessary sensitive customer data in logs.

## Human approval required
- Product publication or removal.
- Any live price, discount, tax, shipping, or warranty-policy change.
- Payment capture, refund, credit, payout, or chargeback submission.
- Purchase orders, supplier contracts, inventory purchases, or other financial commitments.
- External email, SMS, advertising, or social publication.
- Account suspension, fraud accusation, or other adverse customer action.
- Changes to security, access, retention, or privacy controls.

## Evidence and product integrity
- Manufacturer specifications must link to the exact model or official source.
- Documentation must match the exact product and revision where applicable.
- Used products require actual item-specific photographs, condition grading, disclosed defects, and recorded test results.
- Dropship listings must identify the approved supplier and accurately disclose shipping and return terms.
- Unverified claims are omitted or explicitly marked unverified; missing evidence blocks publication.

## Reliability
- All mutating operations must be idempotent.
- Use bounded retries, dead-letter handling, timeouts, and circuit breakers.
- Workers must stop and escalate when data is conflicting, permissions are missing, or confidence is below the task threshold.
- Every task has acceptance criteria and a validation step separate from the worker that performed it.

## Financial and infrastructure constraints
- Prefer existing Cloudflare and J-ROC AI infrastructure.
- No paid model, plugin, SaaS, API, supplier, or advertising commitment without Chairman approval.
- Respect free-tier quotas and implement local or queued fallback where practical.
