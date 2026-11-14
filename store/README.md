# Jrocai.Online Store Foundation

This directory is the isolated retail storefront foundation. It does not replace the existing J-ROC AI platform homepage or private workspaces.

## Current implementation boundary
- Public store shell: `/store/`
- Light-mode-only design.
- J-ROC AI-owned brand and catalog standards.
- Department navigation and product search interface.
- Catalog is intentionally empty until verified product records pass the release gate.
- Manufacturer-sourced candidate register lives in `product-sourcing/candidate-inventory.json`; these are research leads, not sellable inventory.
- No fake products, inventory, prices, ratings, checkout, or payment status.
- Existing platform routes remain untouched.

## Canonical workforce
The connected registry is `../store-workforce/workers.json`: 74 worker definitions across eight departments. Definitions are not deployed workers. Runtime execution requires secure server-side integrations, task authorization, audit logging, and acceptance tests.

## Next implementation stages
1. Inspect and reconcile the existing Supabase project schema.
2. Apply versioned store migrations only after schema inspection.
3. Implement server-side catalog APIs with fail-closed authorization.
4. Add product documentation and approval workflow.
5. Connect customer authentication, cart persistence, checkout, payments, orders, shipping, returns, and support.
6. Add owned inventory and separately identified approved-supplier fulfillment.
7. Add the tested-working pre-owned workflow with item-specific evidence.
8. Connect worker task execution behind approval gates.
9. Run acceptance and security tests before production release.

## Spending and publication controls
No paid services, supplier commitments, purchase orders, or other spending without Chairman approval. No product can be published without verified product facts, required documentation, price and fulfillment disclosures, and an approved release record.
