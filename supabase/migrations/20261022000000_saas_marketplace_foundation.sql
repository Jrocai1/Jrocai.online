-- J-ROC AI SaaS marketplace foundation. Payments remain disabled until tested.
create table if not exists public.saas_products (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  status text not null default 'draft' check (status in ('draft','preview','active','retired')),
  visibility text not null default 'private' check (visibility in ('public','private')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.saas_plans (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.saas_products(id) on delete restrict,
  slug text not null,
  name text not null,
  billing_interval text not null check (billing_interval in ('month','year','one_time')),
  price_cents integer not null check (price_cents >= 0),
  currency text not null default 'usd' check (currency ~ '^[a-z]{3}$'),
  provider_price_id text,
  features jsonb not null default '{}'::jsonb,
  active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(product_id, slug)
);
create table if not exists public.saas_customer_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.saas_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.saas_products(id) on delete restrict,
  plan_id uuid not null references public.saas_plans(id) on delete restrict,
  provider text not null check (provider in ('stripe','manual','other')),
  provider_customer_id text,
  provider_subscription_id text,
  status text not null default 'incomplete' check (status in ('incomplete','trialing','active','past_due','canceled','unpaid','paused','expired')),
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(provider, provider_subscription_id)
);
create table if not exists public.saas_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.saas_products(id) on delete restrict,
  subscription_id uuid references public.saas_subscriptions(id) on delete set null,
  feature_key text not null,
  enabled boolean not null default true,
  limits jsonb not null default '{}'::jsonb,
  valid_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, product_id, feature_key)
);
create table if not exists public.saas_license_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.saas_products(id) on delete restrict,
  subscription_id uuid references public.saas_subscriptions(id) on delete set null,
  key_prefix text not null,
  status text not null default 'pending' check (status in ('pending','active','suspended','revoked','expired')),
  max_activations integer not null default 1 check (max_activations between 1 and 100),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.saas_license_secrets (
  license_id uuid primary key references public.saas_license_records(id) on delete cascade,
  key_hash text not null unique,
  created_at timestamptz not null default now()
);
create table if not exists public.saas_license_activations (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references public.saas_license_records(id) on delete cascade,
  device_fingerprint_hash text not null,
  activated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  deactivated_at timestamptz,
  unique(license_id, device_fingerprint_hash)
);
create table if not exists public.saas_billing_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  processing_status text not null default 'received' check (processing_status in ('received','processing','processed','failed','ignored')),
  processing_error text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique(provider, provider_event_id)
);

create index if not exists saas_subscriptions_user_status_idx on public.saas_subscriptions(user_id, status);
create index if not exists saas_subscriptions_product_idx on public.saas_subscriptions(product_id);
create index if not exists saas_subscriptions_plan_idx on public.saas_subscriptions(plan_id);
create index if not exists saas_entitlements_user_product_idx on public.saas_entitlements(user_id, product_id);
create index if not exists saas_entitlements_product_idx on public.saas_entitlements(product_id);
create index if not exists saas_entitlements_subscription_idx on public.saas_entitlements(subscription_id);
create index if not exists saas_license_records_user_idx on public.saas_license_records(user_id, product_id);
create index if not exists saas_license_records_product_idx on public.saas_license_records(product_id);
create index if not exists saas_license_records_subscription_idx on public.saas_license_records(subscription_id);
create index if not exists saas_license_activations_license_idx on public.saas_license_activations(license_id);
create index if not exists saas_billing_events_status_idx on public.saas_billing_events(processing_status, received_at);

alter table public.saas_products enable row level security;
alter table public.saas_plans enable row level security;
alter table public.saas_customer_profiles enable row level security;
alter table public.saas_subscriptions enable row level security;
alter table public.saas_entitlements enable row level security;
alter table public.saas_license_records enable row level security;
alter table public.saas_license_secrets enable row level security;
alter table public.saas_license_activations enable row level security;
alter table public.saas_billing_events enable row level security;

drop policy if exists "Public can view published SaaS products" on public.saas_products;
create policy "Public can view published SaaS products" on public.saas_products for select to anon, authenticated using (visibility = 'public' and status in ('preview','active'));
drop policy if exists "Public can view active plans for published products" on public.saas_plans;
create policy "Public can view active plans for published products" on public.saas_plans for select to anon, authenticated using (active and exists (select 1 from public.saas_products p where p.id = product_id and p.visibility = 'public' and p.status in ('preview','active')));
drop policy if exists "Customers can read own profile" on public.saas_customer_profiles;
create policy "Customers can read own profile" on public.saas_customer_profiles for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Customers can update own profile" on public.saas_customer_profiles;
create policy "Customers can update own profile" on public.saas_customer_profiles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "Customers can read own subscriptions" on public.saas_subscriptions;
create policy "Customers can read own subscriptions" on public.saas_subscriptions for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Customers can read own entitlements" on public.saas_entitlements;
create policy "Customers can read own entitlements" on public.saas_entitlements for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Customers can read own license records" on public.saas_license_records;
create policy "Customers can read own license records" on public.saas_license_records for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Service-only billing event records" on public.saas_billing_events;
create policy "Service-only billing event records" on public.saas_billing_events for all to anon, authenticated using (false) with check (false);
drop policy if exists "Service-only license secret records" on public.saas_license_secrets;
create policy "Service-only license secret records" on public.saas_license_secrets for all to anon, authenticated using (false) with check (false);
drop policy if exists "Service-only license activation records" on public.saas_license_activations;
create policy "Service-only license activation records" on public.saas_license_activations for all to anon, authenticated using (false) with check (false);

revoke all on public.saas_products, public.saas_plans, public.saas_customer_profiles, public.saas_subscriptions, public.saas_entitlements, public.saas_license_records, public.saas_license_secrets, public.saas_license_activations, public.saas_billing_events from anon, authenticated;
grant select on public.saas_products, public.saas_plans to anon, authenticated;
grant select, update on public.saas_customer_profiles to authenticated;
grant select on public.saas_subscriptions, public.saas_entitlements, public.saas_license_records to authenticated;

create or replace function public.handle_new_saas_customer()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.saas_customer_profiles(user_id, display_name)
  values (new.id, nullif(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (user_id) do nothing;
  return new;
end;
$$;
revoke execute on function public.handle_new_saas_customer() from public, anon, authenticated;
drop trigger if exists on_auth_user_created_saas_profile on auth.users;
create trigger on_auth_user_created_saas_profile after insert on auth.users
for each row execute function public.handle_new_saas_customer();

insert into public.saas_customer_profiles(user_id, display_name)
select id, nullif(raw_user_meta_data ->> 'display_name', '') from auth.users
on conflict (user_id) do nothing;

insert into public.saas_products (slug, name, description, status, visibility, metadata) values
('chairman-office','Chairman Office','Private J-ROC AI platform control center.','draft','private','{"module":"JCO"}'::jsonb),
('ai-hub','J-ROC AI Hub','Shared runtime, platform shell, and governance services.','draft','private','{"module":"JAH"}'::jsonb),
('ai-factory','AI Factory','Template-driven software build and validation pipelines.','draft','private','{"module":"JAF"}'::jsonb),
('ai-app-factory','AI App Factory','Application scaffolding and packaging workflows.','draft','private','{"module":"JAAF"}'::jsonb),
('ai-workers','AI Workers','Governed worker definitions and task execution.','draft','private','{"module":"JAW"}'::jsonb),
('ai-brain','J-ROC AI Brain','Agent planning, validation, and orchestration.','draft','private','{"module":"JAIB"}'::jsonb),
('multi-model-llm','Multi-Model LLM Gateway','Owner-approved model routing and provider controls.','draft','private','{"module":"JLM"}'::jsonb),
('ai-cyber','J-ROC AI Cyber','Defensive diagnostics and security tooling.','draft','private','{"module":"JAIC"}'::jsonb),
('universal-repair-pro','Universal Repair Suite PRO','Apple and Samsung repair-business workflow software.','draft','private','{"module":"JAURSP"}'::jsonb),
('master-brand-kit','Master Brand Kit','Shared brand identity, assets, and design tokens.','draft','private','{"module":"JMBK"}'::jsonb),
('entertainment-studio','Entertainment Studio','Creative project and production workflows.','draft','private','{"module":"JES"}'::jsonb),
('shared-platform-services','Shared Platform Services','Authentication, permissions, licensing, and audit services.','draft','private','{"module":"JPS"}'::jsonb)
on conflict (slug) do nothing;
