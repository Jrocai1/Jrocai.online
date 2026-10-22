# Jrocai.online — J-ROC AI Public Website

A responsive, static public website and searchable product directory for the J-ROC AI ecosystem.

## Deploy on Cloudflare Pages
1. Open Cloudflare Dashboard → **Workers & Pages**.
2. Create a Pages project and connect GitHub.
3. Select `Jrocai1/Jrocai.online`.
4. Select the production branch.
5. Framework preset: **None**.
6. Build command: leave blank.
7. Build output directory: `/` (repository root).
8. Deploy, then attach `jrocai.online` (and optionally `www.jrocai.online`) through Pages custom-domain settings and follow Cloudflare's DNS instructions.

If a Pages project already exists, inspect its settings and deployment first to avoid creating a duplicate. This package does not itself connect to or deploy into the Cloudflare account.

## Product catalog
The product registry is embedded in `index.html` in the `products` array. Add products there and assign an accurate status. Current labels include in development, planned, service, private/planned, and repository available.

## Security boundary
This is a public catalog, not the private Chairman Office dashboard. Never commit secrets, service-role keys, customer data, or private operational endpoints here. The private dashboard must implement server-side authentication and authorization.

## Related projects
- Website: https://github.com/Jrocai1/Jrocai.online
- API: https://github.com/Jrocai1/Jrocai-api
- Universal Repair PRO: https://github.com/Jrocai1/J-ROCAIUniversalRepairPRO

## Verification
Source package is prepared for static hosting. A live Cloudflare deployment, DNS, and HTTPS must be checked in the Cloudflare account after upload.


## Module demos and marketplace
- Demo gallery: `/previews/` — demo links are explicitly labeled and may point to module dashboards until a runnable demo is available.
- SaaS / marketplace catalog: `/marketplace/` — catalog prototype only; checkout and billing are not enabled.
- Private module studio: `/workspace/studio/` — browser-local drafts only until secure repository integration is implemented.

Cloudflare Pages project `jrocai-online` is configured to deploy from `main`, with broad path include patterns to ensure root and nested module changes are observed. Confirm every push by checking that the latest deployment reaches successful build and deploy stages; a skipped deployment is not a release.


## SaaS marketplace backend
- Customer account portal: `/account/`
- Catalog and checkout API: Supabase Edge Function `saas-api`
- Signed Stripe webhook handler: Supabase Edge Function `saas-stripe-webhook`
- Schema and private product registry: `supabase/migrations/20261022000000_saas_marketplace_foundation.sql`
- Source-controlled Edge Function code: `supabase/functions/`
- Launch checklist and required secrets: [docs/SAAS_MARKETPLACE_OPERATIONS.md](docs/SAAS_MARKETPLACE_OPERATIONS.md)

Checkout is intentionally gated off. Products are seeded as private drafts; no active plans or live prices are configured. Do not enable payment collection until Stripe test-mode checkout, signed webhook processing, subscription state, entitlement enforcement, license issuance/revocation, access isolation, cancellation, and refund scenarios pass.

## Website and account foundation verification
See [docs/ACCOUNT_FOUNDATION_TEST_PLAN.md](docs/ACCOUNT_FOUNDATION_TEST_PLAN.md) for current deployment/domain findings, Supabase Auth redirect configuration, owner membership provisioning, and signup/email/password-reset/protected-route acceptance tests. The custom domain remains pending until the registrar nameservers match Cloudflare's assigned nameservers; real email flows still require mailbox testing.
