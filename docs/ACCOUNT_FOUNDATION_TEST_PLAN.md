# Website and account foundation verification

Updated: 2026-10-22

## Current verified infrastructure

- GitHub source: `Jrocai1/Jrocai.online`, production branch `main`.
- Cloudflare Pages project: `jrocai-online`, output directory `/`, no build command.
- Latest verified production deployment before this document: `https://72df432a.jrocai-online.pages.dev/`; build and deploy stages succeeded for commit `0f6cc01b537d43d21aa7387340296f6aaab8e342`.
- Supabase project is active and the workspace-auth and SaaS foundation migrations are applied.
- Public product catalog remains private/internal. There are 12 private product records and zero active subscription plans; checkout must remain disabled.
- Supabase security advisor returned no security lints on the latest check.
- The `workspace_members` table currently has zero rows. No account is yet authorized for the private workspace.

## Account routes

- `/account/`: customer signup/sign-in, customer profile, subscriptions, entitlements, and licenses.
- `/login/`: private workspace sign-in and access request.
- `/workspace/`: requires an authenticated Supabase session and a matching `workspace_members` row.
- `/workspace/studio/`: requires an authenticated Supabase session and a matching `workspace_members` row.
- Customer signup does not create a workspace membership. Workspace access must be explicitly provisioned by the owner.
- Password reset emails now return to `/account/?reset=1`, where the recovery session can submit a new password.
- Email confirmation redirects are configured in source to return to the appropriate account/login page. A real email round trip still requires a live mailbox test.

## Required Supabase Auth URL configuration

In Supabase Dashboard → Authentication → URL Configuration:

1. Set Site URL to `https://jrocai.online` after the domain is active.
2. Add these Redirect URLs:
   - `https://jrocai.online/**`
   - `https://www.jrocai.online/**`
   - `https://jrocai-online.pages.dev/**`
   - `https://*.jrocai-online.pages.dev/**`
3. Confirm email signup is enabled if email confirmation is required.
4. Configure the SMTP sender/domain and verify deliverability. Supabase's default mail service may have delivery/rate limits; do not treat a successful signup API response as proof that mail arrived.
5. Never put a service-role key in website code. The browser may use only the Supabase publishable key.

## Required domain activation

Cloudflare Pages is connected to the repository and its production deployment succeeds. The Cloudflare zone is now **active** and its assigned nameservers are:
- `alfred.ns.cloudflare.com`
- `gail.ns.cloudflare.com`

Cloudflare DNS records are configured:
- `jrocai.online` → CNAME `jrocai-online.pages.dev`
- `www.jrocai.online` → CNAME `jrocai-online.pages.dev`

The Pages custom domain `jrocai.online` has DNS verification status active, but HTTP validation and certificate issuance are still pending. `www.jrocai.online` verification/validation is still pending. Recheck Pages custom-domain status and HTTPS after DNS propagation. Do not change or delete MX, SPF, DKIM, or other email records.

## Manual acceptance checklist

Run these checks after domain and Supabase Auth URL configuration is complete:

1. Open the public home page, then follow Products, Platform, Demos, Marketplace, Customer Account, and Private Workspace Login. Check mobile navigation too.
2. In a private/incognito browser, open `/workspace/` and `/workspace/studio/`. Both must redirect to `/login/` without a session.
3. Create a customer account at `/account/` using a mailbox you control. Verify the confirmation email arrives, open its link, and confirm the browser returns to the site.
4. Sign in to `/account/` and verify the customer dashboard loads. Confirm this does not grant access to `/workspace/`.
5. Request a password reset, open the email link, set and confirm a new password, then sign in with the new password.
6. Sign in to `/login/` with an account that has not been provisioned in `workspace_members`. It must be denied and signed out.
7. After the owner account is confirmed, provision exactly that user in `workspace_members`; then verify workspace and studio access, and verify sign-out redirects back to login.
8. Test a second customer account and confirm it cannot read another customer's subscriptions, entitlements, licenses, or profile data.
9. Confirm checkout is disabled and no plan is active. Do not enable payment until the separate Stripe end-to-end test plan passes.

## Verification status

- [x] GitHub source and Pages project linkage verified.
- [x] Latest checked Pages build and deployment stages succeeded.
- [x] Supabase migrations present and required public tables exist.
- [x] Security advisor reported no security lints.
- [x] Navigation simplified; duplicate login link removed.
- [x] Password-reset page now supports password update after recovery callback.
- [x] Pages DNS records set to the Pages project target in the pending Cloudflare zone.
- [x] Cloudflare zone is active with its assigned nameservers.
- [ ] Custom-domain HTTP validation and HTTPS certificate active.
- [ ] Supabase Site URL / Redirect URL allow-list confirmed in dashboard.
- [ ] Real signup + confirmation email tested with a mailbox.
- [ ] Real password-reset email and password update tested with a mailbox.
- [ ] Owner account created and owner membership provisioned.
- [ ] Protected-route tests completed with both authorized and unauthorized accounts.
