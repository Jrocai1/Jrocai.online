# Store Acceptance Test Plan

This plan distinguishes the current storefront shell from backend features that are not yet implemented.

## Current storefront shell
- [ ] Store loads at /store/ on the existing Cloudflare Pages site.
- [ ] Page is light mode on desktop, tablet, and phone.
- [ ] No dark-mode toggle or dark color-scheme preference exists.
- [ ] Brand colors and typography match the J-ROC AI store standard.
- [ ] Header search submits to the catalog search field.
- [ ] Department navigation scrolls to the correct section.
- [ ] Department filter options are unique and functional.
- [ ] Empty catalog state is clear and does not imply products are available.
- [ ] No invented prices, ratings, stock counts, customer reviews, or product cards appear.
- [ ] Existing root homepage and all current routes remain unchanged.

## Catalog and product release
- [ ] Product records are loaded from the approved database API, not hardcoded demonstration data.
- [ ] Search, department filtering, sorting, and product details work against real records.
- [ ] Draft, pending-review, rejected, and approved publication states are enforced server-side.
- [ ] Missing documentation blocks publication.
- [ ] Manufacturer claims link to exact model-specific evidence.
- [ ] Owned inventory and approved supplier fulfillment are separately identified.
- [ ] Used products require item-specific images, grading, test evidence, defects, and terms.
- [ ] Only Chairman-authorized users can publish or remove products.

## Customer commerce
- [ ] Registration, login, logout, and account recovery.
- [ ] Customer records are isolated by authenticated identity.
- [ ] Cart persistence and server-side price revalidation.
- [ ] Checkout validates stock and shipping eligibility.
- [ ] Payment provider uses hosted or tokenized payment collection.
- [ ] No raw payment card data is stored by this application.
- [ ] Order confirmation and order history reflect actual payment state.
- [ ] Shipment tracking, cancellation, returns, and warranty cases are backed by real records.

## Workforce and administration
- [ ] Registry count equals 74 across eight departments.
- [ ] Registry definitions are not presented as deployed workers.
- [ ] Worker permissions are least-privilege and task-scoped.
- [ ] Missing Chairman credentials fail closed.
- [ ] All mutating operations create audit events.
- [ ] Workers cannot publish products, change live prices, spend money, issue refunds, or place purchase orders without required approval.
- [ ] Retries are bounded and failed jobs are visible for review.

## Security and production
- [ ] Row-Level Security is enabled and tested for every private table.
- [ ] Cross-account tests confirm customers cannot read or change another customer's records.
- [ ] Service-role credentials exist only in server-side secrets.
- [ ] API input validation, rate limiting, and origin controls are tested.
- [ ] No paid services or financial commitments are activated without Chairman approval.
- [ ] Cloudflare deployment is verified at the actual production domain.
- [ ] Rollback and backup procedures are documented.

## Current blockers
- Supabase project restoration was accepted, but its last observed status was COMING_UP and database connections timed out.
- Database schema inspection and migration application are therefore pending.
- Customer checkout, payments, fulfillment, and workforce execution are not represented as live by the current static storefront shell.
