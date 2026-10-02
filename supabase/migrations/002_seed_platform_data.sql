insert into public.subscription_plans (name, slug, description, monthly_price, max_users, max_organizations)
values
  ('Starter', 'starter', 'Entry plan for small teams starting CRM discipline.', 0, 5, 1),
  ('Professional', 'professional', 'Advanced CRM workflows for growing sales teams.', 49, 25, 1),
  ('Business', 'business', 'Operational CRM plan for larger teams and managers.', 149, 100, 1),
  ('Enterprise', 'enterprise', 'Custom governance, scale, and support for enterprise CRM teams.', 0, null, 1)
on conflict (slug) do update
set
  name = excluded.name,
  description = excluded.description,
  monthly_price = excluded.monthly_price,
  max_users = excluded.max_users,
  max_organizations = excluded.max_organizations,
  is_active = true;

insert into public.permissions (key, name, description)
values
  ('crm.read', 'Read CRM data', 'View tenant CRM data.'),
  ('crm.create', 'Create CRM data', 'Create CRM records in the tenant workspace.'),
  ('crm.update', 'Update CRM data', 'Update CRM records in the tenant workspace.'),
  ('crm.delete', 'Delete CRM data', 'Delete CRM records in the tenant workspace.'),
  ('meetings.manage', 'Manage meetings', 'Create and update client meetings.'),
  ('followups.manage', 'Manage follow-ups', 'Create and complete follow-up actions.'),
  ('pipeline.manage', 'Manage pipeline', 'Manage pipeline stages and opportunity progress.'),
  ('documents.manage', 'Manage documents', 'Manage document submission tracking.'),
  ('reports.read', 'Read reports', 'View CRM reporting and analytics.'),
  ('team.read', 'Read team', 'View team members and roles.'),
  ('team.manage', 'Manage team', 'Invite users and manage role assignments.'),
  ('settings.manage', 'Manage settings', 'Manage workspace settings and administrative configuration.'),
  ('subscription.manage', 'Manage subscription', 'Manage billing plan and subscription status.')
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description;
