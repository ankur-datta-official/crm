alter table public.pipeline_stages
add column if not exists color text not null default '#0f766e';

create table if not exists public.industries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  description text,
  status text not null default 'active' check (status in ('active', 'inactive', 'archived')),
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name)
);

create table if not exists public.company_categories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  code text not null,
  description text,
  priority_level integer not null default 3 check (priority_level between 1 and 5),
  status text not null default 'active' check (status in ('active', 'inactive', 'archived')),
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  industry_id uuid references public.industries(id) on delete set null,
  category_id uuid references public.company_categories(id) on delete set null,
  lead_source text,
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high', 'urgent')),
  assigned_user_id uuid references public.profiles(id) on delete set null,
  pipeline_stage_id uuid references public.pipeline_stages(id) on delete set null,
  status text not null default 'active' check (status in ('active', 'inactive', 'archived')),
  phone text,
  whatsapp text,
  email text,
  website text,
  address text,
  city text,
  country text,
  success_rating integer check (success_rating is null or success_rating between 1 and 10),
  lead_temperature text not null default 'warm' check (lead_temperature in ('cold', 'warm', 'hot')),
  estimated_value numeric(14, 2),
  expected_closing_date date,
  notes text,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  updated_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists industries_organization_id_idx on public.industries (organization_id);
create index if not exists company_categories_organization_id_idx on public.company_categories (organization_id);
create index if not exists companies_organization_id_idx on public.companies (organization_id);
create index if not exists companies_search_idx on public.companies (organization_id, name, email, phone, website);
create index if not exists companies_pipeline_stage_id_idx on public.companies (pipeline_stage_id);
create index if not exists companies_assigned_user_id_idx on public.companies (assigned_user_id);

create or replace function public.set_current_updated_by()
returns trigger
language plpgsql
as $$
begin
  new.updated_by = auth.uid();
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_industries_updated_by on public.industries;
create trigger set_industries_updated_by
before update on public.industries
for each row execute function public.set_current_updated_by();

drop trigger if exists set_company_categories_updated_by on public.company_categories;
create trigger set_company_categories_updated_by
before update on public.company_categories
for each row execute function public.set_current_updated_by();

drop trigger if exists set_companies_updated_by on public.companies;
create trigger set_companies_updated_by
before update on public.companies
for each row execute function public.set_current_updated_by();

create or replace function public.seed_crm_base_defaults(target_organization_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.company_categories (organization_id, name, code, description, priority_level, status)
  values
    (target_organization_id, 'A+ High Value', 'A+', 'Top priority accounts with strong value and urgency.', 1, 'active'),
    (target_organization_id, 'A Strong Potential', 'A', 'Strong-fit companies with meaningful potential.', 2, 'active'),
    (target_organization_id, 'B Medium Potential', 'B', 'Viable opportunities needing qualification.', 3, 'active'),
    (target_organization_id, 'C Low Priority', 'C', 'Lower priority opportunities for light nurture.', 4, 'active'),
    (target_organization_id, 'D Not Priority Now', 'D', 'Not a current priority, but retained for future review.', 5, 'active')
  on conflict (organization_id, code) do nothing;
end;
$$;

create or replace function public.seed_crm_defaults_after_organization()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.seed_crm_base_defaults(new.id);
  return new;
end;
$$;

drop trigger if exists seed_crm_defaults_after_organization on public.organizations;
create trigger seed_crm_defaults_after_organization
after insert on public.organizations
for each row execute function public.seed_crm_defaults_after_organization();

select public.seed_crm_base_defaults(id) from public.organizations;

alter table public.industries enable row level security;
alter table public.company_categories enable row level security;
alter table public.companies enable row level security;

drop policy if exists "Organization members can read organization profiles" on public.profiles;
create policy "Organization members can read organization profiles"
on public.profiles for select
to authenticated
using (
  id = auth.uid()
  or public.is_super_admin()
  or organization_id = public.current_organization_id()
);

drop policy if exists "Organization members can manage industries" on public.industries;
create policy "Organization members can manage industries"
on public.industries for all
to authenticated
using (public.is_organization_member(organization_id))
with check (public.is_organization_member(organization_id));

drop policy if exists "Organization members can manage company categories" on public.company_categories;
create policy "Organization members can manage company categories"
on public.company_categories for all
to authenticated
using (public.is_organization_member(organization_id))
with check (public.is_organization_member(organization_id));

drop policy if exists "Organization members can manage companies" on public.companies;
create policy "Organization members can manage companies"
on public.companies for all
to authenticated
using (public.is_organization_member(organization_id))
with check (
  public.is_organization_member(organization_id)
  and (industry_id is null or exists (
    select 1 from public.industries
    where industries.id = companies.industry_id
      and industries.organization_id = companies.organization_id
  ))
  and (category_id is null or exists (
    select 1 from public.company_categories
    where company_categories.id = companies.category_id
      and company_categories.organization_id = companies.organization_id
  ))
  and (pipeline_stage_id is null or exists (
    select 1 from public.pipeline_stages
    where pipeline_stages.id = companies.pipeline_stage_id
      and pipeline_stages.organization_id = companies.organization_id
  ))
);

grant select, insert, update, delete on public.industries to authenticated;
grant select, insert, update, delete on public.company_categories to authenticated;
grant select, insert, update, delete on public.companies to authenticated;
grant insert on public.activity_logs to authenticated;
revoke execute on function public.seed_crm_base_defaults(uuid) from public;
revoke execute on function public.seed_crm_base_defaults(uuid) from authenticated;

drop policy if exists "Organization members can create activity logs" on public.activity_logs;
create policy "Organization members can create activity logs"
on public.activity_logs for insert
to authenticated
with check (public.is_organization_member(organization_id));
