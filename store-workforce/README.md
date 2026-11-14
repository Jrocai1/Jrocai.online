# J-ROC AI Online Store Workforce

This directory defines the specialist AI workforce for Jrocai.Online. It extends the existing 500-agent master registry with store-specific task ownership rather than duplicating the platform-wide agents.

## Current state

- 74 specialist worker definitions are registered.
- All workers are marked `registered_not_deployed`.
- These definitions are not evidence that agents are running, connected to production data, or authorized to take live actions.
- Runtime deployment requires the J-ROC AI Factory / J-Bot runtime, model routing, task queue, database records, tool adapters, secrets, and acceptance testing.

## Workforce hierarchy

1. Chairman: owner and final authority.
2. J-Bot Store Operations Manager: plans and delegates tasks.
3. Department supervisors: coordinate work and quality gates.
4. Specialist workers: execute narrowly scoped tasks.
5. Quality and compliance gates: validate evidence before any release or external action.

## Standard worker contract

Each worker must receive a typed task with:
- unique task identifier and idempotency key
- assigned worker identifier and permitted department scope
- objective, due time, priority, and dependencies
- approved input references and data classification
- allowed tools and permission set
- expected output schema and acceptance criteria

Each result must include:
- status and concise summary
- structured output
- source and evidence references
- confidence, assumptions, and limitations
- validation results
- audit event reference
- approval request when required

## Approval gates

Workers may research, draft, classify, monitor, reconcile, and recommend. They may not independently spend funds, publish listings, change live prices, issue refunds, place supplier orders, alter store policies, or send external marketing campaigns. Those actions require explicit authorization through a human approval workflow.

## Deployment sequence

1. Validate this registry against the existing master agent registry.
2. Implement worker, task, run, evidence, approval, and audit data models.
3. Implement the J-Bot dispatcher and queue with retries and idempotency.
4. Connect read-only store tools first.
5. Add write tools behind approval gates.
6. Test each worker with synthetic data and adversarial cases.
7. Run a monitored pilot before enabling production tasks.

## Files

- `workers.json`: machine-readable worker definitions and operating constraints.
- `WORKFORCE-GOVERNANCE.md`: security, approvals, evidence, and lifecycle rules.
