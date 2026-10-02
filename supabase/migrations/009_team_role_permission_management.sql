-- Migration 009: Team, Role & Permission Management
-- Sprint 10

alter table public.profiles
  add column if not exists department text,
  add column if not exists is_active boolean not null default true;

update public.profiles
set is_active = true
where is_active is null;

create table if not exists public.team_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  email text not null,
  role_id uuid not null references public.roles(id) on delete cascade,
  invited_by uuid references public.profiles(id) on delete set null,
  token text not null unique,
  full_name text,
  job_title text,
  department text,
  phone text,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'cancelled', 'expired')),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists team_invitations_organization_id_idx on public.team_invitations (organization_id);
create index if not exists team_invitations_email_idx on public.team_invitations (email);
create index if not exists team_invitations_token_idx on public.team_invitations (token);

drop trigger if exists set_team_invitations_updated_at on public.team_invitations;
create trigger set_team_invitations_updated_at
before update on public.team_invitations
for each row execute function public.set_updated_at();

alter table public.team_invitations enable row level security;

create or replace function public.is_organization_admin(target_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin()
    or exists (
      select 1
      from public.user_roles ur
      join public.roles r on r.id = ur.role_id
      where ur.organization_id = target_organization_id
        and ur.user_id = auth.uid()
        and r.slug = 'organization-admin'
    );
$$;

create or replace function public.sync_default_role_permissions(target_organization_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  role_record record;
  permission_keys text[];
begin
  update public.roles
  set
    is_system = true,
    name = case slug
      when 'organization-admin' then 'Organization Admin'
      when 'sales-manager' then 'Sales Manager'
      when 'sales-executive' then 'Sales Executive'
      when 'support-user' then 'Support User'
      when 'viewer' then 'Viewer'
      else name
    end,
    description = case slug
      when 'organization-admin' then 'Full access to workspace administration and CRM data.'
      when 'sales-manager' then 'Manage sales team activity, pipeline, and reports.'
      when 'sales-executive' then 'Work assigned leads, meetings, pipeline, and follow-ups.'
      when 'support-user' then 'Assist with support requests and client follow-up needs.'
      when 'viewer' then 'Read-only visibility into CRM data.'
      else description
    end
  where organization_id = target_organization_id
    and slug in ('organization-admin', 'sales-manager', 'sales-executive', 'support-user', 'viewer');

  for role_record in
    select id, slug
    from public.roles
    where organization_id = target_organization_id
      and slug in ('organization-admin', 'sales-manager', 'sales-executive', 'support-user', 'viewer')
  loop
    permission_keys := case role_record.slug
      when 'organization-admin' then array[
        'dashboard.view',
        'companies.view', 'companies.create', 'companies.update', 'companies.archive', 'companies.delete',
        'contacts.view', 'contacts.create', 'contacts.update', 'contacts.archive',
        'meetings.view', 'meetings.create', 'meetings.update', 'meetings.archive',
        'followups.view', 'followups.create', 'followups.update', 'followups.complete', 'followups.cancel', 'followups.archive',
        'documents.view', 'documents.upload', 'documents.update', 'documents.download', 'documents.archive',
        'help_requests.view', 'help_requests.create', 'help_requests.assign', 'help_requests.resolve', 'help_requests.reject', 'help_requests.archive',
        'reports.view', 'reports.export',
        'team.view', 'team.invite', 'team.update_role', 'team.deactivate',
        'settings.view', 'settings.manage',
        'subscription.view', 'subscription.manage'
      ]
      when 'sales-manager' then array[
        'dashboard.view',
        'companies.view', 'companies.create', 'companies.update', 'companies.archive',
        'contacts.view', 'contacts.create', 'contacts.update', 'contacts.archive',
        'meetings.view', 'meetings.create', 'meetings.update', 'meetings.archive',
        'followups.view', 'followups.create', 'followups.update', 'followups.complete', 'followups.cancel', 'followups.archive',
        'documents.view', 'documents.upload', 'documents.update', 'documents.download', 'documents.archive',
        'help_requests.view', 'help_requests.create', 'help_requests.assign', 'help_requests.resolve',
        'reports.view', 'reports.export',
        'team.view'
      ]
      when 'sales-executive' then array[
        'dashboard.view',
        'companies.view', 'companies.create', 'companies.update', 'companies.archive',
        'contacts.view', 'contacts.create', 'contacts.update', 'contacts.archive',
        'meetings.view', 'meetings.create', 'meetings.update',
        'followups.view', 'followups.create', 'followups.update', 'followups.complete', 'followups.cancel',
        'documents.view', 'documents.upload', 'documents.update', 'documents.download'
      ]
      when 'support-user' then array[
        'dashboard.view',
        'companies.view',
        'contacts.view',
        'meetings.view',
        'followups.view', 'followups.create', 'followups.update', 'followups.complete', 'followups.cancel',
        'documents.view', 'documents.upload', 'documents.update', 'documents.download', 'documents.archive',
        'help_requests.view', 'help_requests.create', 'help_requests.assign', 'help_requests.resolve', 'help_requests.reject', 'help_requests.archive'
      ]
      when 'viewer' then array[
        'dashboard.view',
        'companies.view',
        'contacts.view',
        'meetings.view',
        'followups.view',
        'documents.view',
        'help_requests.view',
        'reports.view',
        'team.view',
        'settings.view',
        'subscription.view'
      ]
      else array[]::text[]
    end;

    delete from public.role_permissions
    where role_id = role_record.id;

    insert into public.role_permissions (role_id, permission_id)
    select role_record.id, p.id
    from public.permissions p
    where p.key = any(permission_keys)
    on conflict do nothing;
  end loop;
end;
$$;

create or replace function public.get_team_members_for_current_organization()
returns table (
  id uuid,
  email text,
  full_name text,
  avatar_url text,
  job_title text,
  department text,
  phone text,
  organization_id uuid,
  created_at timestamptz,
  is_active boolean,
  last_login_at timestamptz,
  role_id uuid,
  role_name text,
  role_slug text
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    p.id,
    p.email,
    p.full_name,
    p.avatar_url,
    p.job_title,
    p.department,
    p.phone,
    p.organization_id,
    p.created_at,
    p.is_active,
    au.last_sign_in_at,
    ur.role_id,
    r.name,
    r.slug
  from public.profiles p
  left join public.user_roles ur
    on ur.user_id = p.id
   and ur.organization_id = p.organization_id
  left join public.roles r
    on r.id = ur.role_id
  left join auth.users au
    on au.id = p.id
  where p.organization_id = public.current_organization_id()
  order by coalesce(p.full_name, p.email);
$$;

create or replace function public.get_team_invitation_preview(invite_token text)
returns table (
  id uuid,
  organization_id uuid,
  organization_name text,
  email text,
  full_name text,
  job_title text,
  department text,
  phone text,
  role_id uuid,
  role_name text,
  status text,
  expires_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ti.id,
    ti.organization_id,
    o.name,
    ti.email,
    ti.full_name,
    ti.job_title,
    ti.department,
    ti.phone,
    ti.role_id,
    r.name,
    ti.status,
    ti.expires_at
  from public.team_invitations ti
  join public.organizations o on o.id = ti.organization_id
  left join public.roles r on r.id = ti.role_id
  where ti.token = invite_token
  limit 1;
$$;

create or replace function public.accept_team_invitation(invite_token text)
returns table (
  invitation_id uuid,
  organization_id uuid,
  role_id uuid
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  invitation_record public.team_invitations%rowtype;
  profile_record public.profiles%rowtype;
begin
  if current_user_id is null then
    raise exception 'Authentication is required to accept an invitation.';
  end if;

  insert into public.profiles (id, email, full_name, avatar_url)
  select
    users.id,
    users.email,
    nullif(users.raw_user_meta_data ->> 'full_name', ''),
    nullif(users.raw_user_meta_data ->> 'avatar_url', '')
  from auth.users users
  where users.id = current_user_id
  on conflict (id) do nothing;

  select *
  into invitation_record
  from public.team_invitations
  where token = invite_token
    and status = 'pending'
    and expires_at > now()
  limit 1;

  if invitation_record.id is null then
    raise exception 'Invitation is invalid or expired.';
  end if;

  select *
  into profile_record
  from public.profiles
  where id = current_user_id;

  if profile_record.organization_id is not null and profile_record.organization_id <> invitation_record.organization_id then
    raise exception 'This account already belongs to another organization.';
  end if;

  update public.profiles
  set
    organization_id = invitation_record.organization_id,
    is_active = true,
    full_name = coalesce(public.profiles.full_name, invitation_record.full_name),
    job_title = coalesce(public.profiles.job_title, invitation_record.job_title),
    department = coalesce(public.profiles.department, invitation_record.department),
    phone = coalesce(public.profiles.phone, invitation_record.phone)
  where id = current_user_id;

  delete from public.user_roles
  where organization_id = invitation_record.organization_id
    and user_id = current_user_id;

  insert into public.user_roles (organization_id, user_id, role_id, assigned_by)
  values (
    invitation_record.organization_id,
    current_user_id,
    invitation_record.role_id,
    invitation_record.invited_by
  )
  on conflict (organization_id, user_id, role_id) do nothing;

  update public.team_invitations
  set
    status = 'accepted',
    accepted_at = now(),
    updated_at = now()
  where id = invitation_record.id;

  return query
  select invitation_record.id, invitation_record.organization_id, invitation_record.role_id;
end;
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
  from auth.users users
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
  set
    organization_id = new_organization_id,
    is_active = true
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

  perform public.sync_default_role_permissions(new_organization_id);

  select id into admin_role_id
  from public.roles
  where organization_id = new_organization_id
    and slug = 'organization-admin';

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

insert into public.permissions (key, name, description)
values
  ('dashboard.view', 'View Dashboard', 'View CRM dashboard and statistics.'),
  ('companies.view', 'View Companies', 'View company and lead records.'),
  ('companies.create', 'Create Companies', 'Create new company and lead records.'),
  ('companies.update', 'Update Companies', 'Update company and lead records.'),
  ('companies.archive', 'Archive Companies', 'Archive company and lead records.'),
  ('companies.delete', 'Delete Companies', 'Delete company and lead records permanently.'),
  ('contacts.view', 'View Contacts', 'View contact person records.'),
  ('contacts.create', 'Create Contacts', 'Create new contact person records.'),
  ('contacts.update', 'Update Contacts', 'Update contact person records.'),
  ('contacts.archive', 'Archive Contacts', 'Archive contact person records.'),
  ('meetings.view', 'View Meetings', 'View meeting and interaction log records.'),
  ('meetings.create', 'Create Meetings', 'Create new meeting records.'),
  ('meetings.update', 'Update Meetings', 'Update meeting records.'),
  ('meetings.archive', 'Archive Meetings', 'Archive meeting records.'),
  ('followups.view', 'View Follow-ups', 'View follow-up and reminder records.'),
  ('followups.create', 'Create Follow-ups', 'Create new follow-up records.'),
  ('followups.update', 'Update Follow-ups', 'Update follow-up records.'),
  ('followups.complete', 'Complete Follow-ups', 'Mark follow-up tasks as completed.'),
  ('followups.cancel', 'Cancel Follow-ups', 'Cancel follow-up tasks.'),
  ('followups.archive', 'Archive Follow-ups', 'Archive follow-up records.'),
  ('documents.view', 'View Documents', 'View document records.'),
  ('documents.upload', 'Upload Documents', 'Upload new documents.'),
  ('documents.update', 'Update Documents', 'Update document records.'),
  ('documents.download', 'Download Documents', 'Download document files.'),
  ('documents.archive', 'Archive Documents', 'Archive document records.'),
  ('help_requests.view', 'View Help Requests', 'View need help and escalation records.'),
  ('help_requests.create', 'Create Help Requests', 'Create new help request records.'),
  ('help_requests.assign', 'Assign Help Requests', 'Assign help requests to team members.'),
  ('help_requests.resolve', 'Resolve Help Requests', 'Mark help requests as resolved.'),
  ('help_requests.reject', 'Reject Help Requests', 'Reject help request records.'),
  ('help_requests.archive', 'Archive Help Requests', 'Archive help request records.'),
  ('reports.view', 'View Reports', 'View CRM reports and analytics.'),
  ('reports.export', 'Export Reports', 'Export report data.'),
  ('team.view', 'View Team', 'View team members and invitations.'),
  ('team.invite', 'Invite Team Members', 'Invite new users to the organization.'),
  ('team.update_role', 'Update Team Roles', 'Change user role assignments.'),
  ('team.deactivate', 'Deactivate Team Members', 'Deactivate or reactivate team member access.'),
  ('settings.view', 'View Settings', 'View workspace settings and configuration.'),
  ('settings.manage', 'Manage Settings', 'Update workspace settings and configuration.'),
  ('subscription.view', 'View Subscription', 'View subscription plan and billing details.'),
  ('subscription.manage', 'Manage Subscription', 'Manage subscription plan and billing.')
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description;

drop policy if exists "Profiles can read their own profile" on public.profiles;
drop policy if exists "Profiles can update their own profile" on public.profiles;
drop policy if exists "Profiles can read own or organization profiles" on public.profiles;
drop policy if exists "Profiles can update their own record" on public.profiles;
drop policy if exists "Organization admins can manage profiles" on public.profiles;

create policy "Profiles can read own or organization profiles"
on public.profiles for select
to authenticated
using (
  id = auth.uid()
  or public.is_super_admin()
  or public.is_organization_member(organization_id)
);

create policy "Profiles can update their own record"
on public.profiles for update
to authenticated
using (id = auth.uid() or public.is_super_admin())
with check (id = auth.uid() or public.is_super_admin());

create policy "Organization admins can manage profiles"
on public.profiles for update
to authenticated
using (
  public.is_organization_admin(organization_id)
)
with check (
  public.is_organization_admin(organization_id)
);

drop policy if exists "Organization members can create activity logs" on public.activity_logs;
create policy "Organization members can create activity logs"
on public.activity_logs for insert
to authenticated
with check (
  public.is_organization_member(organization_id)
  and (actor_user_id is null or actor_user_id = auth.uid())
);

drop policy if exists "Organization members can read team invitations" on public.team_invitations;
drop policy if exists "Organization admins can create team invitations" on public.team_invitations;
drop policy if exists "Organization admins can update team invitations" on public.team_invitations;
drop policy if exists "Organization admins can delete team invitations" on public.team_invitations;

create policy "Organization members can read team invitations"
on public.team_invitations for select
to authenticated
using (public.is_organization_member(organization_id));

create policy "Organization admins can create team invitations"
on public.team_invitations for insert
to authenticated
with check (
  public.is_organization_admin(organization_id)
);

create policy "Organization admins can update team invitations"
on public.team_invitations for update
to authenticated
using (public.is_organization_admin(organization_id))
with check (public.is_organization_admin(organization_id));

create policy "Organization admins can delete team invitations"
on public.team_invitations for delete
to authenticated
using (public.is_organization_admin(organization_id));

drop policy if exists "Organization admins can manage user roles" on public.user_roles;
create policy "Organization admins can manage user roles"
on public.user_roles for all
to authenticated
using (public.is_organization_admin(organization_id))
with check (public.is_organization_admin(organization_id));

drop policy if exists "Organization admins can manage roles" on public.roles;
create policy "Organization admins can manage roles"
on public.roles for all
to authenticated
using (public.is_organization_admin(organization_id))
with check (public.is_organization_admin(organization_id));

drop policy if exists "Organization admins can manage role permissions" on public.role_permissions;
create policy "Organization admins can manage role permissions"
on public.role_permissions for all
to authenticated
using (
  public.is_super_admin()
  or exists (
    select 1
    from public.roles r
    where r.id = role_permissions.role_id
      and public.is_organization_admin(r.organization_id)
  )
)
with check (
  public.is_super_admin()
  or exists (
    select 1
    from public.roles r
    where r.id = role_permissions.role_id
      and public.is_organization_admin(r.organization_id)
  )
);

grant select, insert, update, delete on public.team_invitations to authenticated;
grant execute on function public.is_organization_admin(uuid) to authenticated;
grant execute on function public.get_team_members_for_current_organization() to authenticated;
grant execute on function public.get_team_invitation_preview(text) to authenticated;
grant execute on function public.accept_team_invitation(text) to authenticated;
grant execute on function public.sync_default_role_permissions(uuid) to authenticated;
grant execute on function public.create_organization_workspace(text, text) to authenticated;

do $$
declare
  org_record record;
begin
  for org_record in
    select id
    from public.organizations
  loop
    perform public.sync_default_role_permissions(org_record.id);
  end loop;
end;
$$;
