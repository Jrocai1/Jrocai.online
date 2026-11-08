# J-ROC AI Main Workspace Foundation

## Scope
This foundation adds a shared application registry and database-enforced access policies while preserving the existing website, login page, workspace UI, and Website Builder.

## Existing baseline observed
- Main Workspace and Website Builder both initialize Supabase Auth.
- Both check membership in `workspace_members`.
- The Main Workspace module toggles and activity history are currently browser-local.
- The existing login page has no public signup form.

## Role model
- `owner` / `chairman`: full workspace governance and owner-only applications.
- `admin`: application registry and workspace administration.
- `operator`: operational applications and permitted execution workflows.
- `member`: ordinary approved workspace access.

Role names are stored in `workspace_members.role`. The database policies, not the client UI, are the authorization boundary.

## Application registry
The canonical registry is `public.workspace_applications`. Each record has a stable slug, display name, category, route, status, visibility, required roles, sort order, and JSON metadata. The checked-in JSON file is a versioned reference/export; Supabase is the runtime source of truth after migration.

Statuses:
- `available`: route and application are available.
- `development`: application is under active construction.
- `planned`: not yet implemented; do not present it as operational.
- `maintenance`: temporarily unavailable.
- `retired`: no longer offered.

## Apply migration
1. Open the J-ROC AI Supabase project SQL Editor.
2. Review `supabase/migrations/202611070001_workspace_foundation.sql`.
3. Confirm `public.workspace_members` exists and has `user_id` and `role` columns. The current sign-in page already queries those columns.
4. Run the migration.
5. Verify the registry rows and test with separate owner, operator, and member accounts.

The migration does not alter or delete existing membership rows. It adds two tables and two helper functions. It does not create users or enable public signup.

## Important deployment boundary
Committing this migration does not apply it to Supabase. A maintainer must run it in the target project and verify RLS policies before treating permissions as live. The existing frontend membership gate is not a substitute for row-level security. Every future privileged server action must independently verify the caller's role.

## Next implementation steps
1. Connect the Main Workspace navigation and application directory to `workspace_applications`.
2. Add an owner/admin member-management interface with audited role changes.
3. Move module selections and activity from browser storage to per-user database records.
4. Add server-side authorization to every application backend and API.
5. Add route-level access guards to each private application.
