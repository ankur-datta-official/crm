-- Optional demo seed for local or staging environments only.
-- Do not auto-run in production.
-- Safe usage:
-- - run manually only
-- - use only after the core migrations are complete
-- - intended for demos, QA, or staging previews
--
-- Behavior:
-- - Uses the first organization in the database.
-- - Uses the first active profile in that organization.
-- - Inserts only if matching demo records do not already exist.

do $$
declare
  target_org_id uuid;
  target_user_id uuid;
  starter_stage_id uuid;
  software_industry_id uuid;
  services_industry_id uuid;
  high_category_id uuid;
  medium_category_id uuid;
  company_one_id uuid;
  company_two_id uuid;
  contact_one_id uuid;
  contact_two_id uuid;
  interaction_one_id uuid;
  followup_one_id uuid;
  document_one_id uuid;
begin
  select id into target_org_id
  from public.organizations
  order by created_at
  limit 1;

  if target_org_id is null then
    raise notice 'No organization found. Create a workspace before running demo_data.sql.';
    return;
  end if;

  select id into target_user_id
  from public.profiles
  where organization_id = target_org_id
    and is_active = true
  order by created_at
  limit 1;

  if target_user_id is null then
    raise notice 'No active profile found for the target organization.';
    return;
  end if;

  select id into starter_stage_id
  from public.pipeline_stages
  where organization_id = target_org_id
  order by position
  limit 1;

  insert into public.industries (organization_id, name, description, created_by, updated_by)
  values
    (target_org_id, 'Software', 'Demo software industry', target_user_id, target_user_id),
    (target_org_id, 'Professional Services', 'Demo services industry', target_user_id, target_user_id)
  on conflict (organization_id, name) do nothing;

  select id into software_industry_id from public.industries where organization_id = target_org_id and name = 'Software' limit 1;
  select id into services_industry_id from public.industries where organization_id = target_org_id and name = 'Professional Services' limit 1;

  select id into high_category_id from public.company_categories where organization_id = target_org_id order by priority_level asc, created_at asc limit 1;
  select id into medium_category_id from public.company_categories where organization_id = target_org_id order by priority_level asc, created_at asc offset 2 limit 1;

  insert into public.companies (
    organization_id,
    name,
    industry_id,
    category_id,
    lead_source,
    priority,
    assigned_user_id,
    pipeline_stage_id,
    status,
    phone,
    email,
    website,
    city,
    country,
    success_rating,
    lead_temperature,
    estimated_value,
    notes,
    created_by,
    updated_by
  )
  values
    (
      target_org_id,
      'Acme Demo Ltd',
      software_industry_id,
      high_category_id,
      'Referral',
      'high',
      target_user_id,
      starter_stage_id,
      'active',
      '+1 555 0100',
      'hello@acmedemo.test',
      'https://acmedemo.test',
      'New York',
      'USA',
      8,
      'hot',
      45000,
      'Demo account for product walkthroughs.',
      target_user_id,
      target_user_id
    ),
    (
      target_org_id,
      'Northwind Advisory',
      services_industry_id,
      medium_category_id,
      'Website',
      'medium',
      target_user_id,
      starter_stage_id,
      'active',
      '+1 555 0101',
      'ops@northwind.test',
      'https://northwind.test',
      'Chicago',
      'USA',
      6,
      'warm',
      18000,
      'Demo consulting lead.',
      target_user_id,
      target_user_id
    )
  on conflict do nothing;

  select id into company_one_id from public.companies where organization_id = target_org_id and name = 'Acme Demo Ltd' limit 1;
  select id into company_two_id from public.companies where organization_id = target_org_id and name = 'Northwind Advisory' limit 1;

  insert into public.contact_persons (
    organization_id,
    company_id,
    name,
    designation,
    department,
    mobile,
    email,
    decision_role,
    relationship_level,
    preferred_contact_method,
    is_primary,
    status,
    created_by,
    updated_by
  )
  values
    (
      target_org_id,
      company_one_id,
      'Amina Rahman',
      'Operations Manager',
      'Operations',
      '+1 555 0200',
      'amina@acmedemo.test',
      'Influencer',
      'Warm',
      'Email',
      true,
      'active',
      target_user_id,
      target_user_id
    ),
    (
      target_org_id,
      company_two_id,
      'Karim Hasan',
      'Director',
      'Management',
      '+1 555 0201',
      'karim@northwind.test',
      'Director',
      'Known',
      'Phone',
      true,
      'active',
      target_user_id,
      target_user_id
    )
  on conflict do nothing;

  select id into contact_one_id from public.contact_persons where organization_id = target_org_id and email = 'amina@acmedemo.test' limit 1;
  select id into contact_two_id from public.contact_persons where organization_id = target_org_id and email = 'karim@northwind.test' limit 1;

  insert into public.interactions (
    organization_id,
    company_id,
    contact_person_id,
    assigned_user_id,
    interaction_type,
    meeting_datetime,
    discussion_details,
    success_rating,
    lead_temperature,
    next_action,
    next_followup_at,
    need_help,
    status,
    created_by,
    updated_by
  )
  values (
    target_org_id,
    company_one_id,
    contact_one_id,
    target_user_id,
    'Demo Meeting',
    now() - interval '2 days',
    'Walked through the CRM proposal, pricing, and rollout expectations.',
    8,
    'hot',
    'Share the final proposal and schedule a pricing follow-up.',
    now() + interval '2 days',
    false,
    'active',
    target_user_id,
    target_user_id
  )
  on conflict do nothing;

  select id into interaction_one_id
  from public.interactions
  where organization_id = target_org_id
    and company_id = company_one_id
    and interaction_type = 'Demo Meeting'
  order by created_at desc
  limit 1;

  insert into public.followups (
    organization_id,
    company_id,
    contact_person_id,
    interaction_id,
    assigned_user_id,
    followup_type,
    title,
    description,
    scheduled_at,
    reminder_before_minutes,
    status,
    priority,
    created_by,
    updated_by
  )
  values (
    target_org_id,
    company_one_id,
    contact_one_id,
    interaction_one_id,
    target_user_id,
    'Email',
    'Send pricing summary',
    'Share the final proposal summary and next commercial step.',
    now() + interval '1 day',
    60,
    'pending',
    'high',
    target_user_id,
    target_user_id
  )
  on conflict do nothing;

  select id into followup_one_id
  from public.followups
  where organization_id = target_org_id
    and company_id = company_one_id
    and title = 'Send pricing summary'
  order by created_at desc
  limit 1;

  insert into public.documents (
    organization_id,
    company_id,
    contact_person_id,
    interaction_id,
    followup_id,
    document_type,
    title,
    description,
    file_name,
    file_path,
    file_size_mb,
    status,
    submitted_to,
    submitted_at,
    remarks,
    created_by,
    updated_by,
    uploaded_by
  )
  values (
    target_org_id,
    company_one_id,
    contact_one_id,
    interaction_one_id,
    followup_one_id,
    'Quotation',
    'Acme proposal package',
    'Demo metadata only. No storage object is created by this seed.',
    'acme-demo-proposal.pdf',
    target_org_id::text || '/' || company_one_id::text || '/demo/acme-demo-proposal.pdf',
    1.25,
    'submitted',
    'Amina Rahman',
    now() - interval '1 day',
    'Metadata-only demo document record.',
    target_user_id,
    target_user_id,
    target_user_id
  )
  on conflict do nothing;

  select id into document_one_id
  from public.documents
  where organization_id = target_org_id
    and company_id = company_one_id
    and title = 'Acme proposal package'
  order by created_at desc
  limit 1;

  insert into public.help_requests (
    organization_id,
    company_id,
    contact_person_id,
    interaction_id,
    followup_id,
    document_id,
    requested_by,
    assigned_to,
    help_type,
    title,
    description,
    priority,
    status,
    created_by,
    updated_by
  )
  values (
    target_org_id,
    company_one_id,
    contact_one_id,
    interaction_one_id,
    followup_one_id,
    document_one_id,
    target_user_id,
    target_user_id,
    'Need Proposal Support',
    'Review final proposal wording',
    'Demo request to verify pricing language and implementation scope wording.',
    'high',
    'in_progress',
    target_user_id,
    target_user_id
  )
  on conflict do nothing;
end $$;
