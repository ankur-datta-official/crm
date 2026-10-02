-- Migration 011: Legacy permission repair patch
-- Purpose: fix older upgraded environments where permission keys or admin grants were incomplete.
-- Note: fresh installs should follow the default chain through 010, then 012.

-- 1. Fix permission keys - add missing modern permissions
insert into public.permissions (key, name, description) values
  ('dashboard.view', 'View Dashboard', 'View CRM dashboard and statistics.')
on conflict (key) do nothing;

-- Legacy permissions (from migration 002)
insert into public.permissions (key, name, description) values
  ('crm.read', 'Read CRM data', 'View tenant CRM data.')
on conflict (key) do nothing;

-- New detailed permissions (from migration 009)
insert into public.permissions (key, name, description) values
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
on conflict (key) do nothing;

-- 2. Ensure Organization Admin has all permissions
do $$
declare
  admin_roles record;
  all_perms record;
begin
  for admin_roles in
    select r.id as role_id, r.organization_id
    from public.roles r
    where r.slug = 'organization-admin'
  loop
    for all_perms in select id from public.permissions loop
      insert into public.role_permissions (role_id, permission_id)
      values (admin_roles.role_id, all_perms.id)
      on conflict do nothing;
    end loop;
  end loop;
end $$;

-- 3. Ensure Sales Manager has reasonable permissions
do $$
declare
  manager_roles record;
begin
  for manager_roles in
    select r.id as role_id
    from public.roles r
    where r.slug = 'sales-manager'
  loop
    insert into public.role_permissions (role_id, permission_id)
    select manager_roles.role_id, p.id
    from public.permissions p
    where p.key in (
      'crm.read', 'crm.create', 'crm.update',
      'meetings.view', 'meetings.create', 'meetings.update',
      'followups.view', 'followups.create', 'followups.update', 'followups.complete',
      'pipeline.manage',
      'documents.view', 'documents.upload', 'documents.update',
      'reports.view', 'reports.export',
      'team.view'
    )
    on conflict do nothing;
  end loop;
end $$;

-- 4. Ensure Sales Executive has reasonable permissions
do $$
declare
  exec_roles record;
begin
  for exec_roles in
    select r.id as role_id
    from public.roles r
    where r.slug = 'sales-executive'
  loop
    insert into public.role_permissions (role_id, permission_id)
    select exec_roles.role_id, p.id
    from public.permissions p
    where p.key in (
      'crm.read', 'crm.create', 'crm.update',
      'meetings.view', 'meetings.create', 'meetings.update',
      'followups.view', 'followups.create', 'followups.update', 'followups.complete',
      'pipeline.manage',
      'documents.view', 'documents.upload'
    )
    on conflict do nothing;
  end loop;
end $$;

-- 5. Ensure Support User has reasonable permissions
do $$
declare
  support_roles record;
begin
  for support_roles in
    select r.id as role_id
    from public.roles r
    where r.slug = 'support-user'
  loop
    insert into public.role_permissions (role_id, permission_id)
    select support_roles.role_id, p.id
    from public.permissions p
    where p.key in (
      'crm.read', 'crm.create', 'crm.update',
      'followups.view', 'followups.create', 'followups.update', 'followups.complete',
      'documents.view', 'documents.upload', 'documents.update',
      'help_requests.view', 'help_requests.create', 'help_requests.assign', 'help_requests.resolve'
    )
    on conflict do nothing;
  end loop;
end $$;

-- 6. Ensure Viewer has read-only permissions
do $$
declare
  viewer_roles record;
begin
  for viewer_roles in
    select r.id as role_id
    from public.roles r
    where r.slug = 'viewer'
  loop
    insert into public.role_permissions (role_id, permission_id)
    select viewer_roles.role_id, p.id
    from public.permissions p
    where p.key in (
      'crm.read',
      'meetings.view',
      'followups.view',
      'documents.view',
      'reports.view'
    )
    on conflict do nothing;
  end loop;
end $$;
