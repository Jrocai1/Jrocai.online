# J-ROC AI Chairman Suite

**Route:** `/chairman/`  
**Repository:** `Jrocai1/Jrocai.online`  
**Role:** Private executive control surface for J-ROC AI. JCO/Chairman Suite is the authority and governance layer; AI Brain, Hub, Factory, Workers, and product systems remain separate systems.

## Included in this first web-shell release

- Responsive executive dashboard and system directory.
- Supabase Auth session check using the existing project and publishable key.
- Workspace membership lookup against `public.workspace_members`; access is denied if membership cannot be verified.
- Browser-local task queue for interface testing.
- Mission lifecycle, approval policy, audit/recovery, and integration-readiness views.
- Links to the public module directory and existing J-ROC AI repositories.

## Important scope boundary

This is a **web dashboard shell**, not a completed native Chairman OS and not a production automation backend. It does not currently execute privileged actions against GitHub, Cloudflare, Supabase, Windows, or AI workers. The local task list is stored in the current browser only. Approval and audit views are explanatory UI, not durable records.

The browser membership check improves navigation gating but is **not a substitute for server-side authorization**. Every API and database operation must enforce authentication, role/scope policy, and row-level security independently.

## Security lifecycle

Identity → Scope → Policy → Approval → Action → Evidence → Verification → Recovery

- Deny by default; grant least privilege.
- Keep provider tokens and service-role keys out of browser code.
- Require explicit approval for privileged or destructive operations.
- Log actor, request ID, scope, approval, result, timestamp, and verification outcome.
- Provide backup/recovery or rollback before high-impact changes.
- Treat a UI status or a repository link as unverified until an actual integration test returns evidence.

## Configuration

The page currently uses the existing Supabase project URL and public publishable key from the J-ROC AI website. The publishable key is intended for client use; never replace it with a service-role key. It expects the existing `workspace_members` table to be readable by authenticated users under its RLS policies.

## Release gates before calling this production-ready

1. Add server-enforced authorization for every privileged action.
2. Implement a durable task/mission store and approval records with RLS and audit retention.
3. Add authenticated, scope-limited integration APIs for each connected system.
4. Add integration tests for sign-in, membership denial, role boundaries, API errors, and session expiry.
5. Add audit evidence, backups, and tested rollback/recovery.
6. Build the Windows 11 x64 desktop shell/service with authenticated IPC; never give the UI unrestricted host access.
7. Implement signed updates, installer/upgrade tests, and verifiable release artifacts.
8. Complete a Chairman acceptance review before enabling real actions.
