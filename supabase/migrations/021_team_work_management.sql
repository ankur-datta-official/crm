create table if not exists public.team_tasks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'blocked', 'done', 'cancelled')),
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high', 'urgent')),
  progress_percent integer not null default 0 check (progress_percent >= 0 and progress_percent <= 100),
  start_date date,
  due_date date,
  completed_at timestamptz,
  created_by uuid not null references public.profiles(id) on delete cascade,
  assigned_to uuid references public.profiles(id) on delete set null,
  manager_owner_id uuid references public.profiles(id) on delete set null,
  related_entity_type text check (related_entity_type in ('company', 'interaction', 'followup', 'help_request', 'document')),
  related_entity_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.team_task_updates (
  id uuid primary key default gen_random_uuid(),
  team_task_id uuid not null references public.team_tasks(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  author_user_id uuid references public.profiles(id) on delete set null,
  update_type text not null check (update_type in ('created', 'assigned', 'status_changed', 'progress_changed', 'commented', 'completed', 'reopened', 'cancelled')),
  message text,
  previous_status text check (previous_status in ('todo', 'in_progress', 'blocked', 'done', 'cancelled')),
  next_status text check (next_status in ('todo', 'in_progress', 'blocked', 'done', 'cancelled')),
  previous_progress integer check (previous_progress >= 0 and previous_progress <= 100),
  next_progress integer check (next_progress >= 0 and next_progress <= 100),
  created_at timestamptz not null default now()
);

create index if not exists team_tasks_org_assigned_status_due_idx
  on public.team_tasks (organization_id, assigned_to, status, due_date);

create index if not exists team_tasks_org_manager_status_idx
  on public.team_tasks (organization_id, manager_owner_id, status);

create index if not exists team_tasks_org_created_by_created_idx
  on public.team_tasks (organization_id, created_by, created_at desc);

create index if not exists team_task_updates_task_created_idx
  on public.team_task_updates (team_task_id, created_at desc);

create index if not exists team_task_updates_org_created_idx
  on public.team_task_updates (organization_id, created_at desc);

do $$
begin
  if exists (
    select 1
    from pg_proc proc
    join pg_namespace ns
      on ns.oid = proc.pronamespace
    where ns.nspname = 'public'
      and proc.proname = 'set_updated_at'
  ) then
    execute 'drop trigger if exists set_team_tasks_updated_at on public.team_tasks';
    execute '
      create trigger set_team_tasks_updated_at
      before update on public.team_tasks
      for each row
      execute procedure public.set_updated_at()
    ';
  end if;
end $$;

insert into public.permissions (key, name, description)
values
  ('team.tasks.view', 'View Team Tasks', 'Review internal team tasks and work progress in allowed scope.'),
  ('team.tasks.assign', 'Assign Team Tasks', 'Create and assign internal team tasks to managed team members.'),
  ('team.tasks.manage_all', 'Manage All Team Tasks', 'Manage internal team tasks across the full workspace.')
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.key in ('team.tasks.view', 'team.tasks.assign', 'team.tasks.manage_all')
where r.slug = 'organization-admin'
  and r.is_system = true
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.key in ('team.tasks.view', 'team.tasks.assign')
where r.slug = 'sales-manager'
  and r.is_system = true
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p
  on p.key = 'team.tasks.view'
where r.slug in ('sales-executive', 'support-user', 'viewer')
  and r.is_system = true
on conflict do nothing;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated')
     and exists (
       select 1
       from pg_proc proc
       join pg_namespace ns
         on ns.oid = proc.pronamespace
       where ns.nspname = 'public'
         and proc.proname = 'is_organization_member'
     ) then
    execute 'alter table public.team_tasks enable row level security';
    execute 'alter table public.team_task_updates enable row level security';

    execute 'drop policy if exists "Organization members can read team tasks" on public.team_tasks';
    execute '
      create policy "Organization members can read team tasks"
      on public.team_tasks for select
      to authenticated
      using (public.is_organization_member(organization_id))
    ';

    execute 'drop policy if exists "Organization members can manage team tasks" on public.team_tasks';
    execute '
      create policy "Organization members can manage team tasks"
      on public.team_tasks for all
      to authenticated
      using (public.is_organization_member(organization_id))
      with check (public.is_organization_member(organization_id))
    ';

    execute 'drop policy if exists "Organization members can read team task updates" on public.team_task_updates';
    execute '
      create policy "Organization members can read team task updates"
      on public.team_task_updates for select
      to authenticated
      using (public.is_organization_member(organization_id))
    ';

    execute 'drop policy if exists "Organization members can manage team task updates" on public.team_task_updates';
    execute '
      create policy "Organization members can manage team task updates"
      on public.team_task_updates for all
      to authenticated
      using (public.is_organization_member(organization_id))
      with check (public.is_organization_member(organization_id))
    ';

    execute 'grant select, insert, update, delete on public.team_tasks to authenticated';
    execute 'grant select, insert, update, delete on public.team_task_updates to authenticated';
  end if;
end $$;
