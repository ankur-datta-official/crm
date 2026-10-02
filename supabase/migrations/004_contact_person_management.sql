create table if not exists public.contact_persons (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  designation text,
  department text,
  mobile text,
  whatsapp text,
  email text,
  linkedin text,
  decision_role text,
  relationship_level text,
  preferred_contact_method text,
  remarks text,
  is_primary boolean not null default false,
  status text not null default 'active' check (status in ('active', 'inactive', 'archived')),
  created_by uuid references public.profiles(id) on delete set null default auth.uid(),
  updated_by uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists contact_persons_one_primary_per_company_idx
on public.contact_persons (organization_id, company_id)
where is_primary = true and status <> 'archived';

create index if not exists contact_persons_organization_id_idx on public.contact_persons (organization_id);
create index if not exists contact_persons_company_id_idx on public.contact_persons (company_id);
create index if not exists contact_persons_search_idx on public.contact_persons (organization_id, name, mobile, email, designation);

drop trigger if exists set_contact_persons_updated_by on public.contact_persons;
create trigger set_contact_persons_updated_by
before update on public.contact_persons
for each row execute function public.set_current_updated_by();

create or replace function public.ensure_contact_person_tenant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  company_organization_id uuid;
begin
  select organization_id
  into company_organization_id
  from public.companies
  where id = new.company_id;

  if company_organization_id is null then
    raise exception 'Company does not exist.';
  end if;

  if new.organization_id is distinct from company_organization_id then
    raise exception 'Contact organization must match company organization.';
  end if;

  return new;
end;
$$;

drop trigger if exists ensure_contact_person_tenant on public.contact_persons;
create trigger ensure_contact_person_tenant
before insert or update on public.contact_persons
for each row execute function public.ensure_contact_person_tenant();

create or replace function public.enforce_single_primary_contact()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_primary = true and new.status <> 'archived' then
    update public.contact_persons
    set is_primary = false,
        updated_at = now(),
        updated_by = auth.uid()
    where organization_id = new.organization_id
      and company_id = new.company_id
      and id <> new.id
      and is_primary = true;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_single_primary_contact on public.contact_persons;
create trigger enforce_single_primary_contact
before insert or update of is_primary, company_id, status on public.contact_persons
for each row execute function public.enforce_single_primary_contact();

alter table public.contact_persons enable row level security;

drop policy if exists "Organization members can manage contact persons" on public.contact_persons;
create policy "Organization members can manage contact persons"
on public.contact_persons for all
to authenticated
using (public.is_organization_member(organization_id))
with check (
  public.is_organization_member(organization_id)
  and exists (
    select 1
    from public.companies
    where companies.id = contact_persons.company_id
      and companies.organization_id = contact_persons.organization_id
  )
);

grant select, insert, update, delete on public.contact_persons to authenticated;

drop policy if exists "Organization members can create activity logs" on public.activity_logs;
create policy "Organization members can create activity logs"
on public.activity_logs for insert
to authenticated
with check (public.is_organization_member(organization_id));

grant insert on public.activity_logs to authenticated;
