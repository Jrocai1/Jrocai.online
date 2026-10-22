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

Cloudflare Pages project `jrocai-online` is configured to deploy from `main`. When changing source-control deployment settings, verify the newest deployment's stages and ensure the commit was not skipped by path configuration.
