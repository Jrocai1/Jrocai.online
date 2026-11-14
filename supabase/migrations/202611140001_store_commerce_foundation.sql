-- J-ROC AI Store commerce foundation
-- DRAFT ONLY: inspect and review before applying to the connected Supabase project.
-- This migration is intentionally not applied by this commit.
-- All catalog writes, stock changes, supplier records, approvals, and order mutations
-- are server-side only through a trusted service-role API.

create table if not exists public.store_departments (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_products (
  id uuid primary key default gen_random_uuid(),
  department_id uuid references public.store_departments(id) on delete restrict,
  slug text not null unique,
  name text not null,
  short_description text not null default '',
  description text not null default '',
  manufacturer text,
  model_number text,
  product_kind text not null check (product_kind in ('physical','digital','service')),
  inventory_source text not null check (inventory_source in ('owned','approved_supplier','made_to_order','digital')),
  publication_status text not null default 'draft'
    check (publication_status in ('draft','pending_review','approved','published','rejected','archived')),
  condition_type text not null default 'new'
    check (condition_type in ('new','certified_preowned','parts_or_repair')),
  currency text not null default 'usd' check (currency ~ '^[a-z]{3}$'),
  price_cents integer check (price_cents is null or price_cents >= 0),
  compare_at_price_cents integer check (compare_at_price_cents is null or compare_at_price_cents >= 0),
  media jsonb not null default '[]'::jsonb,
  public_attributes jsonb not null default '{}'::jsonb,
  documentation_complete boolean not null default false,
  approved_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (publication_status <> 'published' or (department_id is not null and price_cents is not null and documentation_complete and approved_at is not null and published_at is not null))
);

create table if not exists public.store_product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.store_products(id) on delete cascade,
  sku text not null unique,
  variant_name text not null default 'Default',
  attributes jsonb not null default '{}'::jsonb,
  price_cents integer not null check (price_cents >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_product_documents (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.store_products(id) on delete cascade,
  document_type text not null check (document_type in ('manual','setup','installation','operation','maintenance','troubleshooting','safety','warranty','specification','other')),
  title text not null,
  revision text,
  source_url text,
  storage_path text,
  public_document boolean not null default false,
  verified_for_model boolean not null default false,
  created_at timestamptz not null default now(),
  check (source_url is not null or storage_path is not null)
);

create table if not exists public.store_suppliers (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null,
  website text,
  contact_reference text,
  approval_status text not null default 'pending'
    check (approval_status in ('pending','approved','rejected','suspended')),
  terms_verified_at timestamptz,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_product_supplier_links (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.store_products(id) on delete cascade,
  variant_id uuid references public.store_product_variants(id) on delete cascade,
  supplier_id uuid not null references public.store_suppliers(id) on delete restrict,
  supplier_sku text,
  supplier_cost_cents integer check (supplier_cost_cents is null or supplier_cost_cents >= 0),
  shipping_cost_cents integer check (shipping_cost_cents is null or shipping_cost_cents >= 0),
  currency text not null default 'usd' check (currency ~ '^[a-z]{3}$'),
  stock_checked_at timestamptz,
  stock_quantity integer check (stock_quantity is null or stock_quantity >= 0),
  handling_days_min integer check (handling_days_min is null or handling_days_min >= 0),
  handling_days_max integer check (handling_days_max is null or handling_days_max >= handling_days_min),
  active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_inventory (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.store_product_variants(id) on delete cascade,
  location_code text not null,
  quantity_on_hand integer not null default 0 check (quantity_on_hand >= 0),
  quantity_reserved integer not null default 0 check (quantity_reserved >= 0),
  updated_at timestamptz not null default now(),
  unique (variant_id, location_code),
  check (quantity_reserved <= quantity_on_hand)
);

create table if not exists public.store_product_approvals (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.store_products(id) on delete cascade,
  product_revision text not null,
  decision text not null check (decision in ('approved','rejected','withdrawn')),
  reviewer_user_id uuid references auth.users(id) on delete set null,
  evidence jsonb not null default '[]'::jsonb,
  decision_reason text not null default '',
  decided_at timestamptz not null default now()
);

create table if not exists public.store_preowned_units (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.store_product_variants(id) on delete restrict,
  serial_or_unit_reference text,
  cosmetic_grade text not null check (cosmetic_grade in ('like_new','excellent','good','fair','parts_or_repair')),
  test_status text not null default 'not_tested' check (test_status in ('not_tested','passed','failed')),
  inspection_date timestamptz,
  test_checklist jsonb not null default '[]'::jsonb,
  known_defects text not null default '',
  missing_items text not null default '',
  actual_photo_paths jsonb not null default '[]'::jsonb,
  battery_health_percent integer check (battery_health_percent is null or battery_health_percent between 0 and 100),
  warranty_terms text not null default '',
  return_terms text not null default '',
  sale_status text not null default 'available' check (sale_status in ('available','reserved','sold','withdrawn')),
  created_at timestamptz not null default now(),
  check (cosmetic_grade <> 'parts_or_repair' or test_status <> 'passed')
);

create table if not exists public.store_carts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active','converted','abandoned')),
  currency text not null default 'usd' check (currency ~ '^[a-z]{3}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.store_carts(id) on delete cascade,
  variant_id uuid not null references public.store_product_variants(id) on delete restrict,
  quantity integer not null check (quantity between 1 and 99),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (cart_id, variant_id)
);

create table if not exists public.store_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  user_id uuid references auth.users(id) on delete set null,
  customer_email text not null,
  currency text not null default 'usd' check (currency ~ '^[a-z]{3}$'),
  subtotal_cents integer not null check (subtotal_cents >= 0),
  shipping_cents integer not null default 0 check (shipping_cents >= 0),
  tax_cents integer not null default 0 check (tax_cents >= 0),
  discount_cents integer not null default 0 check (discount_cents >= 0),
  total_cents integer not null check (total_cents >= 0),
  order_status text not null default 'pending' check (order_status in ('pending','confirmed','processing','partially_shipped','shipped','completed','cancelled','refunded')),
  payment_status text not null default 'pending' check (payment_status in ('pending','authorized','paid','failed','partially_refunded','refunded')),
  payment_provider text,
  payment_reference text,
  guest_access_token_hash text unique,
  shipping_address jsonb not null default '{}'::jsonb,
  billing_address jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_inventory_reservations (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null references public.store_product_variants(id) on delete restrict,
  order_id uuid references public.store_orders(id) on delete cascade,
  quantity integer not null check (quantity > 0),
  reservation_status text not null default 'held' check (reservation_status in ('held','committed','released','expired')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.store_payment_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.store_orders(id) on delete cascade,
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  event_status text not null default 'received' check (event_status in ('received','verified','processed','failed','ignored')),
  amount_cents integer check (amount_cents is null or amount_cents >= 0),
  currency text not null default 'usd' check (currency ~ '^[a-z]{3}
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.store_orders(id) on delete cascade,
  product_id uuid references public.store_products(id) on delete set null,
  variant_id uuid references public.store_product_variants(id) on delete set null,
  product_name_snapshot text not null,
  sku_snapshot text,
  quantity integer not null check (quantity between 1 and 99),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  line_total_cents integer not null check (line_total_cents >= 0),
  fulfillment_source text not null check (fulfillment_source in ('owned','approved_supplier','digital','made_to_order')),
  created_at timestamptz not null default now()
);

create table if not exists public.store_shipments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.store_orders(id) on delete cascade,
  carrier text,
  tracking_number text,
  tracking_url text,
  shipment_status text not null default 'pending' check (shipment_status in ('pending','label_created','in_transit','delivered','exception','returned')),
  shipped_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.store_return_requests (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.store_orders(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  reason text not null,
  details text not null default '',
  status text not null default 'requested' check (status in ('requested','under_review','approved','rejected','received','refunded','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_type text not null check (actor_type in ('chairman','staff','worker','system','customer')),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_state jsonb,
  after_state jsonb,
  approval_reference uuid,
  created_at timestamptz not null default now()
);

create index if not exists store_products_public_idx
  on public.store_products (publication_status, department_id, created_at desc);
create index if not exists store_variants_product_idx
  on public.store_product_variants (product_id, active);
create index if not exists store_documents_product_idx
  on public.store_product_documents (product_id, document_type);
create index if not exists store_supplier_links_product_idx
  on public.store_product_supplier_links (product_id, active);
create index if not exists store_orders_user_idx
  on public.store_orders (user_id, created_at desc);
create index if not exists store_order_items_order_idx
  on public.store_order_items (order_id);
create index if not exists store_shipments_order_idx
  on public.store_shipments (order_id);
create index if not exists store_returns_order_idx
  on public.store_return_requests (order_id);

alter table public.store_departments enable row level security;
alter table public.store_products enable row level security;
alter table public.store_product_variants enable row level security;
alter table public.store_product_documents enable row level security;
alter table public.store_suppliers enable row level security;
alter table public.store_product_supplier_links enable row level security;
alter table public.store_inventory enable row level security;
alter table public.store_inventory_reservations enable row level security;
alter table public.store_payment_events enable row level security;
alter table public.store_product_approvals enable row level security;
alter table public.store_preowned_units enable row level security;
alter table public.store_carts enable row level security;
alter table public.store_cart_items enable row level security;
alter table public.store_orders enable row level security;
alter table public.store_order_items enable row level security;
alter table public.store_shipments enable row level security;
alter table public.store_return_requests enable row level security;
alter table public.store_audit_events enable row level security;

drop policy if exists "Published departments are publicly readable" on public.store_departments;
create policy "Published departments are publicly readable"
  on public.store_departments for select to anon, authenticated
  using (active = true);

drop policy if exists "Published products are publicly readable" on public.store_products;
create policy "Published products are publicly readable"
  on public.store_products for select to anon, authenticated
  using (publication_status = 'published');

drop policy if exists "Active variants of published products are publicly readable" on public.store_product_variants;
create policy "Active variants of published products are publicly readable"
  on public.store_product_variants for select to anon, authenticated
  using (active = true and exists (
    select 1 from public.store_products p
    where p.id = product_id and p.publication_status = 'published'
  ));

drop policy if exists "Public documents for published products are readable" on public.store_product_documents;
create policy "Public documents for published products are readable"
  on public.store_product_documents for select to anon, authenticated
  using (public_document = true and exists (
    select 1 from public.store_products p
    where p.id = product_id and p.publication_status = 'published'
  ));

drop policy if exists "Customers can read their own carts" on public.store_carts;
create policy "Customers can read their own carts"
  on public.store_carts for select to authenticated using (user_id = auth.uid());
drop policy if exists "Customers can create their own carts" on public.store_carts;
create policy "Customers can create their own carts"
  on public.store_carts for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Customers can update their own carts" on public.store_carts;
create policy "Customers can update their own carts"
  on public.store_carts for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "Customers can delete their own carts" on public.store_carts;
create policy "Customers can delete their own carts"
  on public.store_carts for delete to authenticated using (user_id = auth.uid());

drop policy if exists "Customers can manage items in their own carts" on public.store_cart_items;
create policy "Customers can manage items in their own carts"
  on public.store_cart_items for all to authenticated
  using (exists (select 1 from public.store_carts c where c.id = cart_id and c.user_id = auth.uid()))
  with check (exists (select 1 from public.store_carts c where c.id = cart_id and c.user_id = auth.uid()));

drop policy if exists "Customers can read their own orders" on public.store_orders;
create policy "Customers can read their own orders"
  on public.store_orders for select to authenticated using (user_id = auth.uid());

drop policy if exists "Customers can read their own order items" on public.store_order_items;
create policy "Customers can read their own order items"
  on public.store_order_items for select to authenticated
  using (exists (select 1 from public.store_orders o where o.id = order_id and o.user_id = auth.uid()));

drop policy if exists "Customers can read their own shipments" on public.store_shipments;
create policy "Customers can read their own shipments"
  on public.store_shipments for select to authenticated
  using (exists (select 1 from public.store_orders o where o.id = order_id and o.user_id = auth.uid()));

drop policy if exists "Customers can read their own return requests" on public.store_return_requests;
create policy "Customers can read their own return requests"
  on public.store_return_requests for select to authenticated
  using (user_id = auth.uid());
drop policy if exists "Customers can request returns for their own orders" on public.store_return_requests;
create policy "Customers can request returns for their own orders"
  on public.store_return_requests for insert to authenticated
  with check (
    user_id = auth.uid()
    and status = 'requested'
    and exists (select 1 from public.store_orders o where o.id = order_id and o.user_id = auth.uid())
  );

-- Supplier costs, inventory counts, pre-owned unit evidence, approvals, audit events,
-- and all administrative writes intentionally have no client policies.
-- Access them only through trusted server-side code using the service role.
),
  provider_reference text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (provider, provider_event_id)
);

create table if not exists public.store_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.store_orders(id) on delete cascade,
  product_id uuid references public.store_products(id) on delete set null,
  variant_id uuid references public.store_product_variants(id) on delete set null,
  product_name_snapshot text not null,
  sku_snapshot text,
  quantity integer not null check (quantity between 1 and 99),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  line_total_cents integer not null check (line_total_cents >= 0),
  fulfillment_source text not null check (fulfillment_source in ('owned','approved_supplier','digital','made_to_order')),
  created_at timestamptz not null default now()
);

create table if not exists public.store_shipments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.store_orders(id) on delete cascade,
  carrier text,
  tracking_number text,
  tracking_url text,
  shipment_status text not null default 'pending' check (shipment_status in ('pending','label_created','in_transit','delivered','exception','returned')),
  shipped_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.store_return_requests (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.store_orders(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  reason text not null,
  details text not null default '',
  status text not null default 'requested' check (status in ('requested','under_review','approved','rejected','received','refunded','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_type text not null check (actor_type in ('chairman','staff','worker','system','customer')),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_state jsonb,
  after_state jsonb,
  approval_reference uuid,
  created_at timestamptz not null default now()
);

create index if not exists store_products_public_idx
  on public.store_products (publication_status, department_id, created_at desc);
create index if not exists store_variants_product_idx
  on public.store_product_variants (product_id, active);
create index if not exists store_documents_product_idx
  on public.store_product_documents (product_id, document_type);
create index if not exists store_supplier_links_product_idx
  on public.store_product_supplier_links (product_id, active);
create index if not exists store_orders_user_idx
  on public.store_orders (user_id, created_at desc);
create index if not exists store_order_items_order_idx
  on public.store_order_items (order_id);
create index if not exists store_shipments_order_idx
  on public.store_shipments (order_id);
create index if not exists store_returns_order_idx
  on public.store_return_requests (order_id);

alter table public.store_departments enable row level security;
alter table public.store_products enable row level security;
alter table public.store_product_variants enable row level security;
alter table public.store_product_documents enable row level security;
alter table public.store_suppliers enable row level security;
alter table public.store_product_supplier_links enable row level security;
alter table public.store_inventory enable row level security;
alter table public.store_product_approvals enable row level security;
alter table public.store_preowned_units enable row level security;
alter table public.store_carts enable row level security;
alter table public.store_cart_items enable row level security;
alter table public.store_orders enable row level security;
alter table public.store_order_items enable row level security;
alter table public.store_shipments enable row level security;
alter table public.store_return_requests enable row level security;
alter table public.store_audit_events enable row level security;

drop policy if exists "Published departments are publicly readable" on public.store_departments;
create policy "Published departments are publicly readable"
  on public.store_departments for select to anon, authenticated
  using (active = true);

drop policy if exists "Published products are publicly readable" on public.store_products;
create policy "Published products are publicly readable"
  on public.store_products for select to anon, authenticated
  using (publication_status = 'published');

drop policy if exists "Active variants of published products are publicly readable" on public.store_product_variants;
create policy "Active variants of published products are publicly readable"
  on public.store_product_variants for select to anon, authenticated
  using (active = true and exists (
    select 1 from public.store_products p
    where p.id = product_id and p.publication_status = 'published'
  ));

drop policy if exists "Public documents for published products are readable" on public.store_product_documents;
create policy "Public documents for published products are readable"
  on public.store_product_documents for select to anon, authenticated
  using (public_document = true and exists (
    select 1 from public.store_products p
    where p.id = product_id and p.publication_status = 'published'
  ));

drop policy if exists "Customers can read their own carts" on public.store_carts;
create policy "Customers can read their own carts"
  on public.store_carts for select to authenticated using (user_id = auth.uid());
drop policy if exists "Customers can create their own carts" on public.store_carts;
create policy "Customers can create their own carts"
  on public.store_carts for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Customers can update their own carts" on public.store_carts;
create policy "Customers can update their own carts"
  on public.store_carts for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "Customers can delete their own carts" on public.store_carts;
create policy "Customers can delete their own carts"
  on public.store_carts for delete to authenticated using (user_id = auth.uid());

drop policy if exists "Customers can manage items in their own carts" on public.store_cart_items;
create policy "Customers can manage items in their own carts"
  on public.store_cart_items for all to authenticated
  using (exists (select 1 from public.store_carts c where c.id = cart_id and c.user_id = auth.uid()))
  with check (exists (select 1 from public.store_carts c where c.id = cart_id and c.user_id = auth.uid()));

drop policy if exists "Customers can read their own orders" on public.store_orders;
create policy "Customers can read their own orders"
  on public.store_orders for select to authenticated using (user_id = auth.uid());

drop policy if exists "Customers can read their own order items" on public.store_order_items;
create policy "Customers can read their own order items"
  on public.store_order_items for select to authenticated
  using (exists (select 1 from public.store_orders o where o.id = order_id and o.user_id = auth.uid()));

drop policy if exists "Customers can read their own shipments" on public.store_shipments;
create policy "Customers can read their own shipments"
  on public.store_shipments for select to authenticated
  using (exists (select 1 from public.store_orders o where o.id = order_id and o.user_id = auth.uid()));

drop policy if exists "Customers can read their own return requests" on public.store_return_requests;
create policy "Customers can read their own return requests"
  on public.store_return_requests for select to authenticated
  using (user_id = auth.uid());
drop policy if exists "Customers can request returns for their own orders" on public.store_return_requests;
create policy "Customers can request returns for their own orders"
  on public.store_return_requests for insert to authenticated
  with check (
    user_id = auth.uid()
    and status = 'requested'
    and exists (select 1 from public.store_orders o where o.id = order_id and o.user_id = auth.uid())
  );

-- Supplier costs, inventory counts, pre-owned unit evidence, approvals, audit events,
-- and all administrative writes intentionally have no client policies.
-- Access them only through trusted server-side code using the service role.
