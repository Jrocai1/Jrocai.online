-- J-ROC AI physical and digital product operations foundation.
-- Additive only: does not alter existing SaaS products, subscriptions, orders or workspace records.
-- Apply after the existing workspace foundation migration because owner policies use jroc_has_workspace_role().

create table if not exists public.jroc_products (
  id uuid primary key default gen_random_uuid(),
  product_code text not null unique,
  slug text not null unique,
  name text not null,
  brand_name text not null default 'J-ROC AI',
  product_type text not null check (product_type in ('physical','digital')),
  division text not null,
  category text not null,
  sourcing_model text not null check (sourcing_model in ('private_label','custom_manufacture','original_design','software_download','subscription','license','digital_content')),
  description text not null default '',
  lifecycle_status text not null default 'draft' check (lifecycle_status in ('draft','research','development','sample_review','quality_review','approved','published','paused','retired','blocked')),
  documentation_status text not null default 'incomplete' check (documentation_status in ('incomplete','in_review','complete')),
  compliance_status text not null default 'not_reviewed' check (compliance_status in ('not_reviewed','review_required','in_review','approved','not_applicable','blocked')),
  quality_status text not null default 'not_reviewed' check (quality_status in ('not_reviewed','in_review','approved','rejected')),
  sku text unique,
  model_number text,
  revision text not null default 'A',
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  retail_price_cents integer check (retail_price_cents is null or retail_price_cents >= 0),
  target_landed_cost_cents integer check (target_landed_cost_cents is null or target_landed_cost_cents >= 0),
  actual_landed_cost_cents integer check (actual_landed_cost_cents is null or actual_landed_cost_cents >= 0),
  target_gross_margin numeric(5,2) check (target_gross_margin is null or target_gross_margin between 0 and 100),
  is_public boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint jroc_product_publication_gate check (
    not is_public or (
      lifecycle_status = 'published'
      and documentation_status = 'complete'
      and compliance_status in ('approved','not_applicable')
      and quality_status = 'approved'
    )
  )
);

create table if not exists public.jroc_suppliers (
  id uuid primary key default gen_random_uuid(),
  legal_name text not null,
  trading_name text,
  website text,
  contact_name text,
  contact_email text,
  country text,
  factory_location text,
  supplier_type text not null default 'manufacturer' check (supplier_type in ('manufacturer','authorized_distributor','contract_manufacturer','software_licensor','other')),
  verification_status text not null default 'unverified' check (verification_status in ('unverified','in_review','verified','rejected','suspended')),
  notes text not null default '',
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.jroc_product_suppliers (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.jroc_products(id) on delete cascade,
  supplier_id uuid not null references public.jroc_suppliers(id) on delete restrict,
  supplier_model text,
  minimum_order_quantity integer check (minimum_order_quantity is null or minimum_order_quantity >= 0),
  quoted_unit_cost_cents integer check (quoted_unit_cost_cents is null or quoted_unit_cost_cents >= 0),
  quoted_currency text not null default 'USD',
  lead_time_days integer check (lead_time_days is null or lead_time_days >= 0),
  private_label_authorized boolean not null default false,
  agreement_reference text,
  approval_status text not null default 'pending' check (approval_status in ('pending','approved','rejected','expired')),
  last_verified_at timestamptz,
  notes text not null default '',
  created_at timestamptz not null default now(),
  unique(product_id, supplier_id, supplier_model)
);

create table if not exists public.jroc_product_documents (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.jroc_products(id) on delete cascade,
  document_type text not null check (document_type in ('user_manual','quick_start','specification','safety_warning','test_report','certificate','declaration','warranty','returns_policy','installation_guide','troubleshooting','maintenance','privacy_notice','license_terms','release_notes','software_bill_of_materials','security_review','other')),
  title text not null,
  storage_path text,
  external_url text,
  version text not null default '1.0',
  language_code text not null default 'en',
  required_for_sale boolean not null default true,
  approval_status text not null default 'pending' check (approval_status in ('pending','approved','rejected','expired')),
  issued_at timestamptz,
  expires_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  notes text not null default '',
  created_at timestamptz not null default now(),
  constraint jroc_document_has_location check (storage_path is not null or external_url is not null)
);

create table if not exists public.jroc_product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.jroc_products(id) on delete cascade,
  review_type text not null check (review_type in ('supplier','sample','quality','compliance','security','documentation','pricing','release')),
  status text not null check (status in ('pending','approved','rejected','needs_changes')),
  reviewer_id uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz not null default now(),
  summary text not null,
  evidence jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.jroc_inventory_lots (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.jroc_products(id) on delete restrict,
  supplier_id uuid references public.jroc_suppliers(id) on delete set null,
  lot_code text not null unique,
  supplier_batch_code text,
  quantity_received integer not null check (quantity_received >= 0),
  quantity_available integer not null check (quantity_available >= 0),
  quantity_reserved integer not null default 0 check (quantity_reserved >= 0),
  quantity_quarantined integer not null default 0 check (quantity_quarantined >= 0),
  unit_cost_cents integer check (unit_cost_cents is null or unit_cost_cents >= 0),
  received_at timestamptz not null default now(),
  inspection_status text not null default 'pending' check (inspection_status in ('pending','passed','failed','quarantined')),
  country_of_origin text,
  notes text not null default '',
  check (quantity_available + quantity_reserved + quantity_quarantined <= quantity_received)
);

create table if not exists public.jroc_inventory_events (
  id uuid primary key default gen_random_uuid(),
  lot_id uuid not null references public.jroc_inventory_lots(id) on delete restrict,
  event_type text not null check (event_type in ('received','reserved','released','shipped','returned','quarantined','adjustment','damaged')),
  quantity integer not null check (quantity > 0),
  reference text,
  actor_id uuid references auth.users(id) on delete set null,
  notes text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.jroc_digital_releases (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.jroc_products(id) on delete cascade,
  version text not null,
  platform text not null,
  artifact_storage_path text,
  artifact_url text,
  checksum_sha256 text,
  release_notes text not null default '',
  minimum_system_requirements jsonb not null default '{}'::jsonb,
  third_party_license_review text not null default 'pending' check (third_party_license_review in ('pending','approved','rejected')),
  security_review text not null default 'pending' check (security_review in ('pending','approved','rejected')),
  release_status text not null default 'draft' check (release_status in ('draft','testing','approved','published','withdrawn')),
  released_at timestamptz,
  created_at timestamptz not null default now(),
  unique(product_id, version, platform),
  constraint jroc_digital_release_has_artifact check (artifact_storage_path is not null or artifact_url is not null or release_status = 'draft')
);

create index if not exists jroc_products_type_status_idx on public.jroc_products(product_type, lifecycle_status);
create index if not exists jroc_products_division_idx on public.jroc_products(division, category);
create index if not exists jroc_product_suppliers_product_idx on public.jroc_product_suppliers(product_id, approval_status);
create index if not exists jroc_product_documents_product_idx on public.jroc_product_documents(product_id, approval_status);
create index if not exists jroc_product_reviews_product_idx on public.jroc_product_reviews(product_id, reviewed_at desc);
create index if not exists jroc_inventory_lots_product_idx on public.jroc_inventory_lots(product_id, received_at desc);
create index if not exists jroc_inventory_events_lot_idx on public.jroc_inventory_events(lot_id, created_at desc);
create index if not exists jroc_digital_releases_product_idx on public.jroc_digital_releases(product_id, release_status);

alter table public.jroc_products enable row level security;
alter table public.jroc_suppliers enable row level security;
alter table public.jroc_product_suppliers enable row level security;
alter table public.jroc_product_documents enable row level security;
alter table public.jroc_product_reviews enable row level security;
alter table public.jroc_inventory_lots enable row level security;
alter table public.jroc_inventory_events enable row level security;
alter table public.jroc_digital_releases enable row level security;

-- Public storefront sees only products that pass every publication gate.
drop policy if exists "Public read approved JROC products" on public.jroc_products;
create policy "Public read approved JROC products" on public.jroc_products
for select to anon, authenticated
using (is_public and lifecycle_status = 'published' and documentation_status = 'complete'
  and compliance_status in ('approved','not_applicable') and quality_status = 'approved');

-- Customers can access approved customer-facing documentation for published products only.
drop policy if exists "Public read approved product documents" on public.jroc_product_documents;
create policy "Public read approved product documents" on public.jroc_product_documents
for select to anon, authenticated
using (approval_status = 'approved' and exists (
  select 1 from public.jroc_products p where p.id = product_id and p.is_public
    and p.lifecycle_status = 'published' and p.documentation_status = 'complete'
    and p.compliance_status in ('approved','not_applicable') and p.quality_status = 'approved'
));

-- All operational records are private to authorized workspace administrators.
drop policy if exists "Product operations admin access" on public.jroc_products;
create policy "Product operations admin access" on public.jroc_products
for all to authenticated
using (public.jroc_has_workspace_role(array['owner','chairman','admin']))
with check (public.jroc_has_workspace_role(array['owner','chairman','admin']));

drop policy if exists "Supplier operations admin access" on public.jroc_suppliers;
create policy "Supplier operations admin access" on public.jroc_suppliers
for all to authenticated
using (public.jroc_has_workspace_role(array['owner','chairman','admin']))
with check (public.jroc_has_workspace_role(array['owner','chairman','admin']));

drop policy if exists "Product supplier links admin access" on public.jroc_product_suppliers;
create policy "Product supplier links admin access" on public.jroc_product_suppliers
for all to authenticated
using (public.jroc_has_workspace_role(array['owner','chairman','admin']))
with check (public.jroc_has_workspace_role(array['owner','chairman','admin']));

drop policy if exists "Product reviews admin access" on public.jroc_product_reviews;
create policy "Product reviews admin access" on public.jroc_product_reviews
for all to authenticated
using (public.jroc_has_workspace_role(array['owner','chairman','admin']))
with check (public.jroc_has_workspace_role(array['owner','chairman','admin']));

drop policy if exists "Inventory lots admin access" on public.jroc_inventory_lots;
create policy "Inventory lots admin access" on public.jroc_inventory_lots
for all to authenticated
using (public.jroc_has_workspace_role(array['owner','chairman','admin']))
with check (public.jroc_has_workspace_role(array['owner','chairman','admin']));

drop policy if exists "Inventory events admin access" on public.jroc_inventory_events;
create policy "Inventory events admin access" on public.jroc_inventory_events
for all to authenticated
using (public.jroc_has_workspace_role(array['owner','chairman','admin']))
with check (public.jroc_has_workspace_role(array['owner','chairman','admin']));

drop policy if exists "Digital releases admin access" on public.jroc_digital_releases;
create policy "Digital releases admin access" on public.jroc_digital_releases
for all to authenticated
using (public.jroc_has_workspace_role(array['owner','chairman','admin']))
with check (public.jroc_has_workspace_role(array['owner','chairman','admin']));

-- Product document writes are admin-only; the public read policy above remains narrowly scoped.
drop policy if exists "Product documents admin write" on public.jroc_product_documents;
create policy "Product documents admin write" on public.jroc_product_documents
for all to authenticated
using (public.jroc_has_workspace_role(array['owner','chairman','admin']))
with check (public.jroc_has_workspace_role(array['owner','chairman','admin']));

revoke all on public.jroc_products, public.jroc_suppliers, public.jroc_product_suppliers,
  public.jroc_product_documents, public.jroc_product_reviews, public.jroc_inventory_lots,
  public.jroc_inventory_events, public.jroc_digital_releases from anon, authenticated;
grant select on public.jroc_products, public.jroc_product_documents to anon, authenticated;
grant select, insert, update, delete on public.jroc_products, public.jroc_suppliers,
  public.jroc_product_suppliers, public.jroc_product_documents, public.jroc_product_reviews,
  public.jroc_inventory_lots, public.jroc_inventory_events, public.jroc_digital_releases to authenticated;

-- Seed only draft concepts. These are not live listings, supplier commitments or inventory.
insert into public.jroc_products
(product_code,slug,name,product_type,division,category,sourcing_model,description,lifecycle_status,documentation_status,compliance_status,quality_status,is_public)
values
('JPH-SMT-001','smart-connectivity-kit','Smart Connectivity Kit','physical','J-ROC AI SmartTech','Connectivity','private_label','Proposed branded hub, cable and adapter bundle. Exact components and compatibility remain to be researched.','research','incomplete','review_required','not_reviewed',false),
('JPH-CMP-001','workstation-dock','Workstation Dock','physical','J-ROC AI Computing','Docks and Hubs','private_label','Proposed multi-port workstation dock. Port capabilities and power ratings require verification.','research','incomplete','review_required','not_reviewed',false),
('JPH-PWR-001','smart-energy-monitor','Smart Energy Monitor','physical','J-ROC AI Power','Energy Monitoring','private_label','Proposed energy monitoring accessory. Electrical installation, measurement claims and exact certification route require review.','research','incomplete','review_required','not_reviewed',false),
('JPH-PWR-002','solar-monitoring-module','Solar Monitoring Module','physical','J-ROC AI OffGrid','Solar Monitoring','private_label','Proposed solar inverter monitoring accessory. Compatibility must be verified by exact inverter model and protocol.','research','incomplete','review_required','not_reviewed',false),
('JPH-MOB-001','ebike-display-family','E-Bike Display Family','physical','J-ROC AI Mobility','Displays','private_label','Proposed display family with separate voltage, connector and communication-protocol variants. No universal compatibility claim.','research','incomplete','review_required','not_reviewed',false),
('JPH-MOB-002','ebike-controller-accessory-kit','E-Bike Controller Accessory Kit','physical','J-ROC AI Mobility','Controllers and Wiring','private_label','Proposed controller and harness accessories. Electrical ratings, firmware, pinout and vehicle compatibility require testing.','research','incomplete','review_required','not_reviewed',false),
('JPH-SUR-001','emergency-lighting-kit','Emergency Lighting Kit','physical','J-ROC AI Survival','Emergency Lighting','private_label','Proposed preparedness lighting kit. Battery transport, runtime and ingress claims require evidence.','research','incomplete','review_required','not_reviewed',false),
('JPH-OFG-001','water-filtration-accessory-kit','Water Filtration Accessory Kit','physical','J-ROC AI OffGrid','Water Filtration','private_label','Proposed filtration accessories. Do not claim potable-water performance without validated test evidence.','research','incomplete','review_required','not_reviewed',false),
('JPH-SEC-001','environmental-sensor-kit','Environmental Sensor Kit','physical','J-ROC AI Security','Sensors','private_label','Proposed environmental sensor bundle. Accuracy, wireless security and supported integrations require testing.','research','incomplete','review_required','not_reviewed',false),
('JPH-SMT-002','rugged-power-cable-kit','Rugged Power Cable Kit','physical','J-ROC AI SmartTech','Cables and Power Accessories','private_label','Proposed cable and power accessory set. Connector, current, temperature and material ratings require validation.','research','incomplete','review_required','not_reviewed',false),
('JDG-REP-001','universal-pro-repair-edition','Universal Pro Repair Edition','digital','J-ROC AI Repair','Repair Software','original_design','J-ROC AI repair workflow and diagnostic software product. Release readiness must be assessed against the current repository build.','development','incomplete','review_required','not_reviewed',false),
('JDG-REP-002','repair-compatibility-library','Repair Compatibility Library','digital','J-ROC AI Repair','Compatibility Data','original_design','Versioned device, connector, firmware and repair compatibility reference library.','draft','incomplete','review_required','not_reviewed',false),
('JDG-ACA-001','universal-repair-academy','Universal Repair Academy','digital','J-ROC AI Academy','Training','digital_content','Structured lessons, labs and learning resources. Publish only complete and tested lessons.','development','incomplete','review_required','not_reviewed',false),
('JDG-FAC-001','enterprise-website-builder','Enterprise Website Builder','digital','J-ROC AI Factory','Website Software','original_design','J-ROC AI website builder with visual editing and AI-assisted creation.','development','incomplete','review_required','not_reviewed',false),
('JDG-BIZ-001','store-operations-suite','Store Operations Suite','digital','J-ROC AI Business','Business Software','original_design','Inventory, catalog, supplier and order operations software.','draft','incomplete','review_required','not_reviewed',false),
('JDG-BIZ-002','business-operations-suite','Business Operations Suite','digital','J-ROC AI Business','Business Software','original_design','Customer, workflow, reporting and business administration tools.','draft','incomplete','review_required','not_reviewed',false),
('JDG-SEC-001','defensive-security-toolkit','Defensive Security Toolkit','digital','J-ROC AI Security','Security Software','original_design','Defensive diagnostics, security education and system-hardening utilities.','draft','incomplete','review_required','not_reviewed',false),
('JDG-MED-001','creator-production-toolkit','Creator Production Toolkit','digital','J-ROC AI Media','Creative Software','original_design','Creator workflows, production templates and owned creative assets.','draft','incomplete','review_required','not_reviewed',false),
('JDG-STR-001','micro-series-platform','Micro-Series Platform','digital','J-ROC AI Streaming','Streaming Software','original_design','Vertical micro-series platform with creator publishing, secure playback and monetization workflows.','development','incomplete','review_required','not_reviewed',false),
('JDG-DOC-001','documentation-builder','Product Documentation Builder','digital','J-ROC AI Factory','Documentation Software','original_design','Reusable manual, setup, maintenance, troubleshooting and release-document generation tools.','draft','incomplete','review_required','not_reviewed',false)
on conflict (product_code) do nothing;
