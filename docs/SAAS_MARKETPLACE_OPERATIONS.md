# J-ROC AI SaaS Marketplace — Operations and Release Gate

## Current implementation

- Supabase database: product registry, plans, customer profiles, subscriptions, entitlements, billing event ledger, license records, one-way license-key hashes, and device activations.
- Supabase Edge Functions: `saas-api` and `saas-stripe-webhook`.
- Website: `/marketplace/` uses the API when published products exist and falls back to a clearly labeled internal catalog.
- Customer portal: `/account/` supports Supabase account creation/sign-in, own subscription/entitlement/license views, license issue, and license revoke.
- All 12 initial module products are seeded as `draft` and `private`. No plans are active, and no real checkout is enabled.
- License keys are generated only for users with an active `product_access` entitlement. Only a SHA-256 hash is stored; the full key is returned once.
- Billing event IDs are unique per provider and webhook signatures are checked before processing. Subscription events update subscription status and product entitlements.

## Required secrets — configure in Supabase, never commit them

Set these through the Supabase project's Edge Function secrets interface:

- `STRIPE_SECRET_KEY` — start with a Stripe **test-mode** secret key.
- `STRIPE_WEBHOOK_SECRET` — signing secret for the webhook endpoint.

Webhook endpoint:

`https://dfgiqvjepytgvjyxszqe.supabase.co/functions/v1/saas-stripe-webhook`

Subscribe to these Stripe events:
- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`

Do not set `SAAS_CHECKOUT_ENABLED=true` until the full test checklist below passes. The API requires both Stripe secrets, a public product, an active monthly/yearly plan with a Stripe Price ID, and this explicit flag before it can start checkout. No secret is placed in browser code.

## Publish a product safely

1. Verify the module's working demo, support policy, compatibility matrix, data handling, and release artifact.
2. Create a Stripe test-mode recurring Price and store its ID in `saas_plans.provider_price_id`.
3. Add a plan with a real amount/currency, the correct interval, and `active=false` initially.
4. Test with the plan and product in non-public state; confirm no checkout is offered.
5. Change the product to `preview` or `active` and `visibility=public` only when approved. Set the plan active only for a test run.
6. Run all checkout/webhook/entitlement/license tests in Stripe test mode.
7. Keep the explicit checkout flag disabled until all tests pass and the owner authorizes launch.
8. For public launch, use production Stripe keys and production webhook secret, repeat the full test suite, review legal/tax/refund/support requirements, then enable checkout deliberately.

## End-to-end test checklist

- [ ] Customer can create an account and complete email confirmation.
- [ ] Invalid login is rejected; password reset sends a generic safe response.
- [ ] Customer A cannot read Customer B's subscriptions, entitlements, profile, or license records.
- [ ] Anonymous users cannot read billing events, license hashes, or activations.
- [ ] Draft/private products and inactive plans do not appear in the public catalog.
- [ ] Checkout returns a disabled response while `SAAS_CHECKOUT_ENABLED` is not exactly `true`.
- [ ] Checkout rejects unknown, inactive, one-time, private, or unmapped plans.
- [ ] Stripe test checkout creates a subscription and signed webhook events update the database.
- [ ] Replaying the same Stripe event is idempotent.
- [ ] Invalid signatures and stale webhook timestamps are rejected.
- [ ] Canceled/past-due subscriptions disable entitlements according to the release policy.
- [ ] License issuance fails without a current entitlement and returns a key only once when entitled.
- [ ] License activation checks key hash, status, expiry, entitlement, and activation limit.
- [ ] Revoking a license deactivates its activations.
- [ ] Customer can cancel through the provider's secure billing flow; local status follows verified webhooks.
- [ ] Refunds, failed payments, webhook retries, and access revocation are tested before live payments.
- [ ] A production deployment and rollback are verified before launch.

## Current blockers

- Stripe secrets and webhook configuration are not confirmed as installed.
- There are zero active subscription plans; catalog entries remain private drafts.
- Checkout is intentionally disabled; no payments should be accepted yet.
- The accessible GitHub integration currently exposes `Jrocai1` repositories, but the referenced JCO and AI Factory repositories under `Jrocaiplatiform` are not accessible through this connection. Their actual source cannot be connected or verified until that GitHub access is granted or the correct repositories are linked.
- The Universal Repair Suite PRO demo has a separate successful Cloudflare Pages build; real hardware integrations still require individual device testing.
