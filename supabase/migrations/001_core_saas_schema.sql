create extension if not exists pgcrypto;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  company_size text,
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  description text,
  monthly_price numeric(10, 2) not null default 0,
  max_users integer,
  max_organizations integer not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.organization_subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id) on delete restrict,
  status text not null default 'trialing' check (status in ('trialing', 'active', 'past_due', 'canceled', 'expired')),
  trial_starts_at timestamptz not null default now(),
  trial_ends_at timestamptz not null default now() + interval '14 days',
  current_period_starts_at timestamptz,
  current_period_ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id)
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete set null,
  email text not null,
  full_name text,
  avatar_url text,
  job_title text,
  phone text,
  is_super_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  slug text not null,
  description text,
  is_system boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, slug)
);

create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default now(),
  unique (organization_id, user_id, role_id)
);

create table if not exists public.pipeline_stages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  slug text not null,
  position integer not null,
  probability integer not null default 0 check (probability >= 0 and probability <= 100),
  is_won boolean not null default false,
  is_lost boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, slug),
  unique (organization_id, position)
);

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_organizations_updated_at on public.organizations;
create trigger set_organizations_updated_at
before update on public.organizations
for each row execute function public.set_updated_at();

drop trigger if exists set_organization_subscriptions_updated_at on public.organization_subscriptions;
create trigger set_organization_subscriptions_updated_at
before update on public.organization_subscriptions
for each row execute function public.set_updated_at();

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_roles_updated_at on public.roles;
create trigger set_roles_updated_at
before update on public.roles
for each row execute function public.set_updated_at();

drop trigger if exists set_pipeline_stages_updated_at on public.pipeline_stages;
create trigger set_pipeline_stages_updated_at
before update on public.pipeline_stages
for each row execute function public.set_updated_at();

create or replace function public.is_super_admin()
returns boolean
language sql
stable
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'is_super_admin')::boolean, false);
$$;

create or replace function public.current_organization_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select organization_id from public.profiles where id = auth.uid();
$$;

create or replace function public.is_organization_member(target_organization_id uuid)
returns boolean
language sql
stable
as $$
  select public.is_super_admin()
    or target_organization_id = public.current_organization_id();
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do update
  set
    email = excluded.email,
    full_name = coalesce(public.profiles.full_name, excluded.full_name),
    avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.slugify(value text)
returns text
language sql
immutable
as $$
  select trim(both '-' from regexp_replace(lower(coalesce(value, '')), '[^a-z0-9]+', '-', 'g'));
$$;

create or replace function public.create_organization_workspace(
  workspace_name text,
  company_size_text text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  current_email text;
  existing_organization_id uuid;
  new_organization_id uuid;
  starter_plan_id uuid;
  admin_role_id uuid;
  manager_role_id uuid;
  executive_role_id uuid;
  support_role_id uuid;
  viewer_role_id uuid;
  base_slug text;
  final_slug text;
begin
  if current_user_id is null then
    raise exception 'Authentication is required to create a workspace.';
  end if;

  insert into public.profiles (id, email, full_name, avatar_url)
  select
    users.id,
    users.email,
    nullif(users.raw_user_meta_data ->> 'full_name', ''),
    nullif(users.raw_user_meta_data ->> 'avatar_url', '')
  from auth.users
  where users.id = current_user_id
  on conflict (id) do nothing;

  select organization_id, email
  into existing_organization_id, current_email
  from public.profiles
  where id = current_user_id;

  if existing_organization_id is not null then
    return existing_organization_id;
  end if;

  if nullif(trim(workspace_name), '') is null then
    raise exception 'Workspace name is required.';
  end if;

  select id into starter_plan_id
  from public.subscription_plans
  where slug = 'starter'
  limit 1;

  if starter_plan_id is null then
    raise exception 'Starter subscription plan is missing. Run seed migration first.';
  end if;

  base_slug := public.slugify(workspace_name);
  if base_slug = '' then
    base_slug := 'workspace';
  end if;
  final_slug := base_slug || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);

  insert into public.organizations (name, slug, company_size, owner_user_id)
  values (trim(workspace_name), final_slug, nullif(trim(company_size_text), ''), current_user_id)
  returning id into new_organization_id;

  update public.profiles
  set organization_id = new_organization_id
  where id = current_user_id;

  insert into public.organization_subscriptions (organization_id, plan_id, status)
  values (new_organization_id, starter_plan_id, 'trialing');

  insert into public.roles (organization_id, name, slug, description)
  values
    (new_organization_id, 'Organization Admin', 'organization-admin', 'Full access to workspace administration and CRM data.'),
    (new_organization_id, 'Sales Manager', 'sales-manager', 'Manage sales team activity, pipeline, and reports.'),
    (new_organization_id, 'Sales Executive', 'sales-executive', 'Work assigned leads, meetings, pipeline, and follow-ups.'),
    (new_organization_id, 'Support User', 'support-user', 'Assist with support requests and client follow-up needs.'),
    (new_organization_id, 'Viewer', 'viewer', 'Read-only visibility into CRM data.');

  select id into admin_role_id from public.roles where organization_id = new_organization_id and slug = 'organization-admin';
  select id into manager_role_id from public.roles where organization_id = new_organization_id and slug = 'sales-manager';
  select id into executive_role_id from public.roles where organization_id = new_organization_id and slug = 'sales-executive';
  select id into support_role_id from public.roles where organization_id = new_organization_id and slug = 'support-user';
  select id into viewer_role_id from public.roles where organization_id = new_organization_id and slug = 'viewer';

  insert into public.role_permissions (role_id, permission_id)
  select admin_role_id, id from public.permissions
  on conflict do nothing;

  insert into public.role_permissions (role_id, permission_id)
  select manager_role_id, id from public.permissions
  where key in (
    'crm.read', 'crm.create', 'crm.update', 'meetings.manage', 'followups.manage',
    'pipeline.manage', 'documents.manage', 'reports.read', 'team.read'
  )
  on conflict do nothing;

  insert into public.role_permissions (role_id, permission_id)
  select executive_role_id, id from public.permissions
  where key in ('crm.read', 'crm.create', 'crm.update', 'meetings.manage', 'followups.manage', 'pipeline.manage', 'documents.manage')
  on conflict do nothing;

  insert into public.role_permissions (role_id, permission_id)
  select support_role_id, id from public.permissions
  where key in ('crm.read', 'followups.manage', 'documents.manage')
  on conflict do nothing;

  insert into public.role_permissions (role_id, permission_id)
  select viewer_role_id, id from public.permissions
  where key in ('crm.read', 'reports.read')
  on conflict do nothing;

  insert into public.user_roles (organization_id, user_id, role_id, assigned_by)
  values (new_organization_id, current_user_id, admin_role_id, current_user_id);

  insert into public.pipeline_stages (organization_id, name, slug, position, probability, is_won, is_lost)
  values
    (new_organization_id, 'New Lead', 'new-lead', 1, 5, false, false),
    (new_organization_id, 'Contacted', 'contacted', 2, 10, false, false),
    (new_organization_id, 'Meeting Scheduled', 'meeting-scheduled', 3, 25, false, false),
    (new_organization_id, 'Meeting Done', 'meeting-done', 4, 35, false, false),
    (new_organization_id, 'Requirement Collected', 'requirement-collected', 5, 45, false, false),
    (new_organization_id, 'Proposal Sent', 'proposal-sent', 6, 60, false, false),
    (new_organization_id, 'Negotiation', 'negotiation', 7, 75, false, false),
    (new_organization_id, 'Won', 'won', 8, 100, true, false),
    (new_organization_id, 'Lost', 'lost', 9, 0, false, true),
    (new_organization_id, 'Hold', 'hold', 10, 20, false, false);

  insert into public.activity_logs (organization_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (
    new_organization_id,
    current_user_id,
    'workspace.created',
    'organization',
    new_organization_id,
    jsonb_build_object('workspace_name', workspace_name, 'user_email', current_email)
  );

  return new_organization_id;
end;
$$;

alter table public.organizations enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.organization_subscriptions enable row level security;
alter table public.profiles enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_roles enable row level security;
alter table public.pipeline_stages enable row level security;
alter table public.activity_logs enable row level security;

drop policy if exists "Subscription plans are readable by authenticated users" on public.subscription_plans;
create policy "Subscription plans are readable by authenticated users"
on public.subscription_plans for select
to authenticated
using (is_active = true or public.is_super_admin());

drop policy if exists "Permissions are readable by authenticated users" on public.permissions;
create policy "Permissions are readable by authenticated users"
on public.permissions for select
to authenticated
using (true);

drop policy if exists "Profiles can read their own profile" on public.profiles;
create policy "Profiles can read their own profile"
on public.profiles for select
to authenticated
using (id = auth.uid() or public.is_super_admin());

drop policy if exists "Profiles can update their own profile" on public.profiles;
create policy "Profiles can update their own profile"
on public.profiles for update
to authenticated
using (id = auth.uid() or public.is_super_admin())
with check (id = auth.uid() or public.is_super_admin());

drop policy if exists "Organization members can read their organization" on public.organizations;
create policy "Organization members can read their organization"
on public.organizations for select
to authenticated
using (public.is_organization_member(id));

drop policy if exists "Organization members can read their subscription" on public.organization_subscriptions;
create policy "Organization members can read their subscription"
on public.organization_subscriptions for select
to authenticated
using (public.is_organization_member(organization_id));

drop policy if exists "Organization members can read roles" on public.roles;
create policy "Organization members can read roles"
on public.roles for select
to authenticated
using (public.is_organization_member(organization_id));

drop policy if exists "Organization members can read role permissions" on public.role_permissions;
create policy "Organization members can read role permissions"
on public.role_permissions for select
to authenticated
using (
  public.is_super_admin()
  or exists (
    select 1
    from public.roles
    where roles.id = role_permissions.role_id
      and roles.organization_id = public.current_organization_id()
  )
);

drop policy if exists "Organization members can read user roles" on public.user_roles;
create policy "Organization members can read user roles"
on public.user_roles for select
to authenticated
using (public.is_organization_member(organization_id));

drop policy if exists "Organization members can read pipeline stages" on public.pipeline_stages;
create policy "Organization members can read pipeline stages"
on public.pipeline_stages for select
to authenticated
using (public.is_organization_member(organization_id));

drop policy if exists "Organization members can manage pipeline stages" on public.pipeline_stages;
create policy "Organization members can manage pipeline stages"
on public.pipeline_stages for all
to authenticated
using (public.is_organization_member(organization_id))
with check (public.is_organization_member(organization_id));

drop policy if exists "Organization members can read activity logs" on public.activity_logs;
create policy "Organization members can read activity logs"
on public.activity_logs for select
to authenticated
using (public.is_organization_member(organization_id));

grant usage on schema public to authenticated;
grant select on public.subscription_plans to authenticated;
grant select, update on public.profiles to authenticated;
grant select on public.organizations to authenticated;
grant select on public.organization_subscriptions to authenticated;
grant select on public.roles to authenticated;
grant select on public.permissions to authenticated;
grant select on public.role_permissions to authenticated;
grant select on public.user_roles to authenticated;
grant select, insert, update, delete on public.pipeline_stages to authenticated;
grant select on public.activity_logs to authenticated;

grant execute on function public.create_organization_workspace(text, text) to authenticated;
grant execute on function public.current_organization_id() to authenticated;
grant execute on function public.is_organization_member(uuid) to authenticated;
