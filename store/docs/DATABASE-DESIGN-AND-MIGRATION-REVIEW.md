# Store Database Design and Migration Review

## Existing Supabase baseline (read-only inspection, 2026-11-14)

Project: `jrocai-online-workspace-auth`  
Project status: `ACTIVE_HEALTHY`  
Applied migration history: 7 migrations (workspace authentication, SaaS marketplace, security tuning, customer profile trigger, private product registry, trigger restriction, and J-ROC language-model controls).

The public schema contains existing SaaS product, plan, subscription, entitlement, license, billing-event, customer-profile, workspace, and J-ROC AI model-control tables. Those existing tables are not being repurposed as physical store inventory or retail orders.

No store-specific inventory, cart, order, supplier, or product-document tables were found in the inspected public schema.

## Proposed store entities

- Departments, products, variants, and product documents.
- Supplier records and product-to-supplier terms, including cost and stock verification timestamps.
- Owned inventory and unit-level Certified Pre-Owned evidence.
- Product approval history and audit events.
- Customer carts and cart items.
- Orders, order-item snapshots, shipments, and return requests.

## Security model

- Public clients can read only active departments, published products, active variants of published products, and explicitly public documentation.
- Customers can read and manage only their own carts.
- Customers can read only their own orders, order items, shipments, and return requests; they can create return requests only for their own orders.
- Supplier costs, stock counts, pre-owned inspection evidence, approvals, audit events, and all catalog/order writes are server-side only.
- No payment-card data is stored. A payment provider reference may be recorded after a separately approved payment integration.
- The service-role key must never be sent to browsers or committed to source control.

## Migration file

`202611140001_store_commerce_foundation.sql` is a proposed migration. It has been committed for review only and has NOT been applied to Supabase.

Before applying:
1. Review the SQL against the full current schema and naming conventions.
2. Validate all policy subqueries and privileges in a staging project.
3. Add migration tests, especially cross-account isolation and unauthenticated catalog reads.
4. Confirm Chairman role assignment and approval identity model.
5. Confirm storage bucket policies for product images and documentation.
6. Apply only after explicit approval and a backup/rollback plan.

## Existing security findings to resolve separately

The Supabase security advisor reports:
- `public.jroc_llm_limits`: row-level security enabled, no policies.
- `public.jroc_llm_provider_health`: row-level security enabled, no policies.
- Leaked-password protection is disabled in Supabase Auth.

These findings predate this store migration. Do not weaken existing controls or add permissive policies just to silence the advisor. Review intended server-only access and enable compromised-password protection in the Auth settings after owner approval.
