alter table public.companies drop constraint if exists companies_lead_temperature_check;
alter table public.companies
add constraint companies_lead_temperature_check
check (lead_temperature in ('cold', 'warm', 'hot', 'very_hot'));

create table if not exists public.interactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  contact_person_id uuid references public.contact_persons(id) on delete set null,
  assigned_user_id uuid references public.profiles(id) on delete set null,
  interaction_type text not null default 'Phone Call',
  meeting_datetime timestamptz not null default now(),
  location text,
  online_meeting_link text,
  discussion_details text not null,
  client_requirement text,
  pain_point text,
  proposed_solution text,
  budget_discussion text,
  competitor_mentioned text,
  decision_timeline text,
  success_rating integer check (success_rating is null or success_rating between 1 and 10),
  lead_temperature text check (lead_temperature is null or lead_temperature in ('cold', 'warm', 'hot', 'very_hot')),
  next_action text,
  next_followup_at timestamptz,
  need_help boolean not null default false,
  internal_note text,
  status text not null default 'active' check (status in ('active', 'inactive', 'archived')),
  created_by uuid references public.profiles(id) on delete set null default auth.uid(),
  updated_by uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists interactions_organization_id_idx on public.interactions (organization_id);
create index if not exists interactions_company_id_idx on public.interactions (company_id);
create index if not exists interactions_contact_person_id_idx on public.interactions (contact_person_id);
create index if not exists interactions_meeting_datetime_idx on public.interactions (meeting_datetime);

drop trigger if exists set_interactions_updated_by on public.interactions;
create trigger set_interactions_updated_by
before update on public.interactions
for each row execute function public.set_current_updated_by();

create or replace function public.ensure_interaction_tenant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  company_organization_id uuid;
  contact_company_id uuid;
  contact_organization_id uuid;
begin
  select organization_id into company_organization_id
  from public.companies
  where id = new.company_id;

  if company_organization_id is null then
    raise exception 'Company does not exist.';
  end if;

  if new.organization_id is distinct from company_organization_id then
    raise exception 'Interaction organization must match company organization.';
  end if;

  if new.contact_person_id is not null then
    select company_id, organization_id
    into contact_company_id, contact_organization_id
    from public.contact_persons
    where id = new.contact_person_id;

    if contact_company_id is distinct from new.company_id or contact_organization_id is distinct from new.organization_id then
      raise exception 'Contact person must belong to the selected company and organization.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists ensure_interaction_tenant on public.interactions;
create trigger ensure_interaction_tenant
before insert or update on public.interactions
for each row execute function public.ensure_interaction_tenant();

alter table public.interactions enable row level security;

drop policy if exists "Organization members can manage interactions" on public.interactions;
create policy "Organization members can manage interactions"
on public.interactions for all
to authenticated
using (public.is_organization_member(organization_id))
with check (
  public.is_organization_member(organization_id)
  and exists (
    select 1 from public.companies
    where companies.id = interactions.company_id
      and companies.organization_id = interactions.organization_id
  )
  and (
    contact_person_id is null
    or exists (
      select 1 from public.contact_persons
      where contact_persons.id = interactions.contact_person_id
        and contact_persons.company_id = interactions.company_id
        and contact_persons.organization_id = interactions.organization_id
    )
  )
);

grant select, insert, update, delete on public.interactions to authenticated;
grant insert on public.activity_logs to authenticated;
