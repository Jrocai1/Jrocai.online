-- J-ROC AI Main Workspace foundation
-- Apply in Supabase SQL Editor after confirming workspace_members(user_id, role) exists.
-- This migration does not modify or delete existing member records.

create extension if not exists pgcrypto;

create or replace function public.jroc_is_workspace_member()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.workspace_members wm
    where wm.user_id = auth.uid()
  );
$$;

create or replace function public.jroc_has_workspace_role(allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.workspace_members wm
    where wm.user_id = auth.uid()
      and lower(coalesce(wm.role, 'member')) = any (
        select lower(role_name) from unnest(allowed_roles) as role_name
      )
  );
$$;

revoke all on function public.jroc_is_workspace_member() from public;
revoke all on function public.jroc_has_workspace_role(text[]) from public;
grant execute on function public.jroc_is_workspace_member() to authenticated;
grant execute on function public.jroc_has_workspace_role(text[]) to authenticated;

create table if not exists public.workspace_applications (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  category text not null default 'Platform',
  route text not null unique,
  icon text not null default 'app',
  status text not null default 'planned'
    check (status in ('available','development','planned','maintenance','retired')),
  visibility text not null default 'workspace'
    check (visibility in ('public','workspace','owner')),
  required_roles text[] not null default array['member']::text[],
  sort_order integer not null default 100,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists workspace_applications_sort_idx
  on public.workspace_applications(sort_order, name);
create index if not exists workspace_applications_status_idx
  on public.workspace_applications(status);

create table if not exists public.workspace_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  resource_type text not null,
  resource_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists workspace_audit_events_created_idx
  on public.workspace_audit_events(created_at desc);
create index if not exists workspace_audit_events_actor_idx
  on public.workspace_audit_events(actor_user_id, created_at desc);

alter table public.workspace_applications enable row level security;
alter table public.workspace_audit_events enable row level security;

drop policy if exists "Members read permitted workspace applications" on public.workspace_applications;
create policy "Members read permitted workspace applications"
on public.workspace_applications for select to authenticated
using (
  public.jroc_is_workspace_member()
  and (
    visibility = 'workspace'
    or (visibility = 'owner' and public.jroc_has_workspace_role(array['owner','chairman','admin']))
  )
  and (
    cardinality(required_roles) = 0
    or exists (
      select 1 from public.workspace_members wm
      where wm.user_id = auth.uid()
        and lower(coalesce(wm.role, 'member')) = any (
          select lower(role_name) from unnest(required_roles) as role_name
        )
    )
    or public.jroc_has_workspace_role(array['owner','chairman','admin'])
  )
);

drop policy if exists "Administrators manage workspace applications" on public.workspace_applications;
create policy "Administrators manage workspace applications"
on public.workspace_applications for all to authenticated
using (public.jroc_has_workspace_role(array['owner','chairman','admin']))
with check (public.jroc_has_workspace_role(array['owner','chairman','admin']));

drop policy if exists "Members read own audit events" on public.workspace_audit_events;
create policy "Members read own audit events"
on public.workspace_audit_events for select to authenticated
using (
  public.jroc_has_workspace_role(array['owner','chairman','admin'])
  or actor_user_id = auth.uid()
);

drop policy if exists "Members write own audit events" on public.workspace_audit_events;
create policy "Members write own audit events"
on public.workspace_audit_events for insert to authenticated
with check (actor_user_id = auth.uid() and public.jroc_is_workspace_member());

insert into public.workspace_applications
  (slug,name,description,category,route,icon,status,visibility,required_roles,sort_order)
values
  ('main-workspace','Main Workspace','Central navigation, application access, and workspace operations.','Core Platform','/workspace/','home','available','workspace',array['member'],10),
  ('chairman-office','Chairman Office','Executive control center and owner-level administration.','Control Center','/chairman/','crown','development','owner',array['owner','chairman'],20),
  ('ai-factory','J-ROC AI Factory','Software build orchestration and project lifecycle.','Builders','/factory/','factory','development','workspace',array['operator','admin','owner','chairman'],30),
  ('website-builder','Enterprise Website Builder','Visual website editing and AI-assisted website workflows.','Builders','/workspace/website-builder/','globe','development','workspace',array['member'],40),
  ('ai-intelligence','AI Intelligence Center','AI system status, model routing, and intelligence tools.','AI Systems','/ai/','brain','planned','workspace',array['member'],50),
  ('agent-center','AI Agent Center','Agent directory, permissions, and worker orchestration.','AI Systems','/agents/','agents','planned','workspace',array['operator','admin','owner','chairman'],60),
  ('model-center','Model Management','Approved model catalog and local-first model gateway controls.','AI Systems','/models/','models','planned','workspace',array['operator','admin','owner','chairman'],70),
  ('repair-edition','Universal Pro Repair Edition','Device diagnostics and contactless repair workflows.','Products','/repair/','repair','development','workspace',array['member'],80),
  ('repair-academy','Universal Repair Academy','Training, learning paths, labs, and certifications.','Products','/academy/','academy','planned','workspace',array['member'],90),
  ('business-center','Business Operations','Business workflows, customers, inventory, and reporting.','Business','/business/','business','planned','workspace',array['operator','admin','owner','chairman'],100),
  ('creative-studio','Creative Studio','Music, media, and creative production workspace.','Creative','/creative/','creative','planned','workspace',array['member'],110),
  ('workspace-settings','Workspace Settings','Member administration, role policy, and workspace configuration.','Administration','/workspace/settings/','settings','development','owner',array['owner','chairman','admin'],120)
on conflict (slug) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  route = excluded.route,
  icon = excluded.icon,
  sort_order = excluded.sort_order,
  updated_at = now();

-- No public signup is enabled here. Provision users through Supabase Auth
-- and add approved user IDs to workspace_members using a trusted admin process.
