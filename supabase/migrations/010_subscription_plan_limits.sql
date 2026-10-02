-- Migration 010: Subscription Plan Limits & SaaS Packaging
-- Sprint 11

alter table public.subscription_plans
  add column if not exists max_companies integer,
  add column if not exists storage_limit_mb integer,
  add column if not exists file_size_limit_mb integer,
  add column if not exists custom_pipeline boolean not null default false,
  add column if not exists pdf_export boolean not null default false,
  add column if not exists csv_import boolean not null default false,
  add column if not exists advanced_reports boolean not null default false,
  add column if not exists audit_log boolean not null default false;

insert into public.subscription_plans (
  name,
  slug,
  description,
  monthly_price,
  max_users,
  max_organizations,
  max_companies,
  storage_limit_mb,
  file_size_limit_mb,
  custom_pipeline,
  pdf_export,
  csv_import,
  advanced_reports,
  audit_log
)
values
  (
    'Starter',
    'starter',
    'Entry plan for small teams starting CRM discipline.',
    0,
    3,
    1,
    500,
    1024,
    10,
    false,
    false,
    false,
    false,
    false
  ),
  (
    'Professional',
    'professional',
    'Advanced CRM workflows for growing sales teams.',
    49,
    10,
    1,
    5000,
    10240,
    25,
    true,
    true,
    true,
    true,
    true
  ),
  (
    'Business',
    'business',
    'Operational CRM plan for larger teams and managers.',
    149,
    30,
    1,
    25000,
    51200,
    50,
    true,
    true,
    true,
    true,
    true
  ),
  (
    'Enterprise',
    'enterprise',
    'Custom governance, scale, and support for enterprise CRM teams.',
    0,
    null,
    1,
    null,
    null,
    null,
    true,
    true,
    true,
    true,
    true
  )
on conflict (slug) do update
set
  name = excluded.name,
  description = excluded.description,
  monthly_price = excluded.monthly_price,
  max_users = excluded.max_users,
  max_organizations = excluded.max_organizations,
  max_companies = excluded.max_companies,
  storage_limit_mb = excluded.storage_limit_mb,
  file_size_limit_mb = excluded.file_size_limit_mb,
  custom_pipeline = excluded.custom_pipeline,
  pdf_export = excluded.pdf_export,
  csv_import = excluded.csv_import,
  advanced_reports = excluded.advanced_reports,
  audit_log = excluded.audit_log,
  is_active = true;

drop policy if exists "Organization admins can update their subscription" on public.organization_subscriptions;
create policy "Organization admins can update their subscription"
on public.organization_subscriptions for update
to authenticated
using (public.is_organization_admin(organization_id))
with check (public.is_organization_admin(organization_id));

grant update on public.organization_subscriptions to authenticated;
