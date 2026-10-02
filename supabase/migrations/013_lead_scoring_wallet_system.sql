-- Migration 013: Lead scoring, wallet rewards, and gamification backend

alter table public.profiles
  add column if not exists wallet_balance integer not null default 0,
  add column if not exists wallet_lifetime_earned integer not null default 0;

alter table public.companies
  add column if not exists lead_score integer not null default 0,
  add column if not exists referred_by_user_id uuid references public.profiles(id) on delete set null;

create index if not exists companies_referred_by_user_id_idx on public.companies (referred_by_user_id);

create table if not exists public.lead_score_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  action_key text not null,
  name text not null,
  description text,
  points integer not null default 0,
  is_active boolean not null default true,
  rule_scope jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, action_key)
);

create table if not exists public.lead_source_score_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  source_name text not null,
  normalized_source text not null,
  bonus_points integer not null default 0,
  is_active boolean not null default true,
  rule_scope jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, normalized_source)
);

create table if not exists public.challenge_templates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  description text,
  cadence text not null check (cadence in ('daily', 'weekly')),
  target_metric text not null,
  target_count integer not null check (target_count > 0),
  bonus_points integer not null default 0,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.rewards_catalog (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  description text,
  reward_type text not null check (reward_type in ('badge', 'discount', 'premium_feature', 'manual_reward')),
  cost_points integer not null check (cost_points >= 0),
  feature_key text,
  inventory integer,
  fulfillment_mode text not null default 'manual' check (fulfillment_mode in ('automatic', 'manual')),
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  transaction_type text not null check (transaction_type in ('earn', 'bonus', 'redeem', 'adjustment', 'refund')),
  action_key text not null,
  points_delta integer not null check (points_delta <> 0),
  balance_after integer not null,
  company_id uuid references public.companies(id) on delete set null,
  followup_id uuid references public.followups(id) on delete set null,
  challenge_id uuid references public.challenge_templates(id) on delete set null,
  reward_id uuid references public.rewards_catalog(id) on delete set null,
  source_record_id uuid,
  source_record_type text,
  idempotency_key text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, idempotency_key)
);

create table if not exists public.user_challenge_progress (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  challenge_template_id uuid not null references public.challenge_templates(id) on delete cascade,
  progress_count integer not null default 0,
  target_count integer not null,
  is_completed boolean not null default false,
  completed_at timestamptz,
  bonus_awarded_transaction_id uuid references public.wallet_transactions(id) on delete set null,
  window_starts_at timestamptz not null,
  window_ends_at timestamptz not null,
  last_event_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id, challenge_template_id, window_starts_at)
);

create table if not exists public.user_streaks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  streak_key text not null,
  current_streak integer not null default 0,
  best_streak integer not null default 0,
  last_activity_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id, streak_key)
);

create table if not exists public.reward_redemptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reward_id uuid not null references public.rewards_catalog(id) on delete restrict,
  points_spent integer not null check (points_spent >= 0),
  status text not null default 'pending' check (status in ('pending', 'fulfilled', 'rejected', 'cancelled')),
  fulfillment_notes text,
  processed_by uuid references public.profiles(id) on delete set null,
  processed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_badges (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reward_id uuid references public.rewards_catalog(id) on delete set null,
  badge_key text not null,
  badge_name text not null,
  badge_description text,
  metadata jsonb not null default '{}'::jsonb,
  awarded_at timestamptz not null default now(),
  awarded_by uuid references public.profiles(id) on delete set null,
  unique (organization_id, user_id, badge_key)
);

create table if not exists public.scoring_activity_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  wallet_transaction_id uuid references public.wallet_transactions(id) on delete set null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_user_id uuid references public.profiles(id) on delete set null,
  action_key text not null,
  title text not null,
  description text,
  points_delta integer not null,
  company_id uuid references public.companies(id) on delete set null,
  followup_id uuid references public.followups(id) on delete set null,
  challenge_id uuid references public.challenge_templates(id) on delete set null,
  reward_id uuid references public.rewards_catalog(id) on delete set null,
  source_record_id uuid,
  source_record_type text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists lead_score_rules_org_action_idx
  on public.lead_score_rules (organization_id, action_key);
create index if not exists lead_source_score_rules_org_source_idx
  on public.lead_source_score_rules (organization_id, normalized_source);
create index if not exists wallet_transactions_org_user_created_idx
  on public.wallet_transactions (organization_id, user_id, created_at desc);
create index if not exists wallet_transactions_org_action_created_idx
  on public.wallet_transactions (organization_id, action_key, created_at desc);
create index if not exists wallet_transactions_company_idx
  on public.wallet_transactions (company_id, created_at desc);
create index if not exists scoring_activity_logs_org_user_created_idx
  on public.scoring_activity_logs (organization_id, user_id, created_at desc);
create index if not exists scoring_activity_logs_company_idx
  on public.scoring_activity_logs (company_id, created_at desc);
create index if not exists challenge_templates_org_metric_idx
  on public.challenge_templates (organization_id, target_metric, is_active);
create index if not exists user_challenge_progress_org_user_idx
  on public.user_challenge_progress (organization_id, user_id, updated_at desc);
create index if not exists reward_redemptions_org_user_idx
  on public.reward_redemptions (organization_id, user_id, created_at desc);
create index if not exists user_badges_org_user_idx
  on public.user_badges (organization_id, user_id, awarded_at desc);

drop trigger if exists set_lead_score_rules_updated_at on public.lead_score_rules;
create trigger set_lead_score_rules_updated_at
before update on public.lead_score_rules
for each row execute function public.set_updated_at();

drop trigger if exists set_lead_source_score_rules_updated_at on public.lead_source_score_rules;
create trigger set_lead_source_score_rules_updated_at
before update on public.lead_source_score_rules
for each row execute function public.set_updated_at();

drop trigger if exists set_challenge_templates_updated_at on public.challenge_templates;
create trigger set_challenge_templates_updated_at
before update on public.challenge_templates
for each row execute function public.set_updated_at();

drop trigger if exists set_rewards_catalog_updated_at on public.rewards_catalog;
create trigger set_rewards_catalog_updated_at
before update on public.rewards_catalog
for each row execute function public.set_updated_at();

drop trigger if exists set_user_challenge_progress_updated_at on public.user_challenge_progress;
create trigger set_user_challenge_progress_updated_at
before update on public.user_challenge_progress
for each row execute function public.set_updated_at();

drop trigger if exists set_user_streaks_updated_at on public.user_streaks;
create trigger set_user_streaks_updated_at
before update on public.user_streaks
for each row execute function public.set_updated_at();

drop trigger if exists set_reward_redemptions_updated_at on public.reward_redemptions;
create trigger set_reward_redemptions_updated_at
before update on public.reward_redemptions
for each row execute function public.set_updated_at();

create or replace function public.normalize_lead_source(value text)
returns text
language sql
immutable
as $$
  select lower(trim(coalesce(value, '')));
$$;

create or replace function public.get_score_action_title(action_key text)
returns text
language sql
immutable
as $$
  select case action_key
    when 'lead_created' then 'Lead created'
    when 'lead_qualified' then 'Lead qualified'
    when 'lead_converted_won' then 'Lead converted to won'
    when 'followup_completed' then 'Follow-up completed'
    when 'lead_source_bonus' then 'Lead source bonus'
    when 'weekly_conversion_bonus' then 'Weekly conversion bonus'
    when 'lead_referral' then 'Lead referral reward'
    when 'team_invite_accepted' then 'Team invite reward'
    when 'challenge_bonus' then 'Challenge completed'
    when 'reward_redeemed' then 'Reward redeemed'
    when 'manual_adjustment' then 'Manual wallet adjustment'
    else replace(initcap(replace(action_key, '_', ' ')), '  ', ' ')
  end;
$$;

create or replace function public.calculate_challenge_window_start(cadence text, happened_at timestamptz)
returns timestamptz
language sql
immutable
as $$
  select case
    when cadence = 'daily' then date_trunc('day', happened_at)
    else date_trunc('week', happened_at)
  end;
$$;

create or replace function public.calculate_challenge_window_end(cadence text, happened_at timestamptz)
returns timestamptz
language sql
immutable
as $$
  select case
    when cadence = 'daily' then date_trunc('day', happened_at) + interval '1 day'
    else date_trunc('week', happened_at) + interval '1 week'
  end;
$$;

create or replace function public.update_scoring_streak(
  p_organization_id uuid,
  p_user_id uuid,
  p_streak_key text,
  p_happened_at timestamptz default now()
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  streak_record public.user_streaks%rowtype;
  activity_date date := (p_happened_at at time zone 'UTC')::date;
  next_current integer := 1;
  next_best integer := 1;
begin
  select *
  into streak_record
  from public.user_streaks
  where organization_id = p_organization_id
    and user_id = p_user_id
    and streak_key = p_streak_key
  for update;

  if not found then
    insert into public.user_streaks (
      organization_id,
      user_id,
      streak_key,
      current_streak,
      best_streak,
      last_activity_date
    )
    values (
      p_organization_id,
      p_user_id,
      p_streak_key,
      1,
      1,
      activity_date
    );
    return;
  end if;

  if streak_record.last_activity_date = activity_date then
    return;
  end if;

  if streak_record.last_activity_date = activity_date - 1 then
    next_current := streak_record.current_streak + 1;
  end if;

  next_best := greatest(streak_record.best_streak, next_current);

  update public.user_streaks
  set
    current_streak = next_current,
    best_streak = next_best,
    last_activity_date = activity_date
  where id = streak_record.id;
end;
$$;

create or replace function public.award_wallet_points(
  p_organization_id uuid,
  p_user_id uuid,
  p_transaction_type text,
  p_action_key text,
  p_points_delta integer,
  p_company_id uuid default null,
  p_followup_id uuid default null,
  p_challenge_id uuid default null,
  p_reward_id uuid default null,
  p_source_record_id uuid default null,
  p_source_record_type text default null,
  p_idempotency_key text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_created_by uuid default auth.uid(),
  p_add_to_lead_score boolean default true
)
returns table (
  transaction_id uuid,
  points_delta integer,
  balance_after integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_balance integer;
  next_balance integer;
  tx public.wallet_transactions%rowtype;
begin
  if p_points_delta = 0 then
    raise exception 'Points delta cannot be zero.';
  end if;

  if p_idempotency_key is not null then
    select *
    into tx
    from public.wallet_transactions
    where organization_id = p_organization_id
      and idempotency_key = p_idempotency_key;

    if found then
      return query
      select tx.id, tx.points_delta, tx.balance_after;
      return;
    end if;
  end if;

  select wallet_balance
  into current_balance
  from public.profiles
  where id = p_user_id
    and organization_id = p_organization_id
  for update;

  if current_balance is null then
    raise exception 'Wallet profile not found for user %.', p_user_id;
  end if;

  next_balance := current_balance + p_points_delta;

  if next_balance < 0 then
    raise exception 'Insufficient wallet balance.';
  end if;

  insert into public.wallet_transactions (
    organization_id,
    user_id,
    transaction_type,
    action_key,
    points_delta,
    balance_after,
    company_id,
    followup_id,
    challenge_id,
    reward_id,
    source_record_id,
    source_record_type,
    idempotency_key,
    metadata,
    created_by
  )
  values (
    p_organization_id,
    p_user_id,
    p_transaction_type,
    p_action_key,
    p_points_delta,
    next_balance,
    p_company_id,
    p_followup_id,
    p_challenge_id,
    p_reward_id,
    p_source_record_id,
    p_source_record_type,
    coalesce(p_idempotency_key, gen_random_uuid()::text),
    coalesce(p_metadata, '{}'::jsonb),
    p_created_by
  )
  returning *
  into tx;

  update public.profiles
  set
    wallet_balance = next_balance,
    wallet_lifetime_earned = wallet_lifetime_earned + greatest(p_points_delta, 0)
  where id = p_user_id
    and organization_id = p_organization_id;

  if p_company_id is not null and p_add_to_lead_score and p_points_delta > 0 then
    update public.companies
    set lead_score = lead_score + p_points_delta
    where id = p_company_id
      and organization_id = p_organization_id;
  end if;

  insert into public.scoring_activity_logs (
    organization_id,
    wallet_transaction_id,
    user_id,
    actor_user_id,
    action_key,
    title,
    description,
    points_delta,
    company_id,
    followup_id,
    challenge_id,
    reward_id,
    source_record_id,
    source_record_type,
    metadata
  )
  values (
    p_organization_id,
    tx.id,
    p_user_id,
    p_created_by,
    p_action_key,
    public.get_score_action_title(p_action_key),
    coalesce(p_metadata ->> 'description', null),
    p_points_delta,
    p_company_id,
    p_followup_id,
    p_challenge_id,
    p_reward_id,
    p_source_record_id,
    p_source_record_type,
    coalesce(p_metadata, '{}'::jsonb)
  );

  return query
  select tx.id, tx.points_delta, tx.balance_after;
end;
$$;

create or replace function public.sync_challenge_progress_from_event(
  p_organization_id uuid,
  p_user_id uuid,
  p_action_key text,
  p_happened_at timestamptz default now(),
  p_company_id uuid default null,
  p_followup_id uuid default null,
  p_source_record_id uuid default null,
  p_source_record_type text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_actor_user_id uuid default auth.uid()
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  template_record record;
  progress_record public.user_challenge_progress%rowtype;
  window_start timestamptz;
  window_end timestamptz;
  awarded_tx record;
begin
  for template_record in
    select *
    from public.challenge_templates
    where organization_id = p_organization_id
      and target_metric = p_action_key
      and is_active = true
      and (starts_at is null or starts_at <= p_happened_at)
      and (ends_at is null or ends_at >= p_happened_at)
  loop
    window_start := public.calculate_challenge_window_start(template_record.cadence, p_happened_at);
    window_end := public.calculate_challenge_window_end(template_record.cadence, p_happened_at);

    insert into public.user_challenge_progress (
      organization_id,
      user_id,
      challenge_template_id,
      progress_count,
      target_count,
      window_starts_at,
      window_ends_at,
      last_event_at
    )
    values (
      p_organization_id,
      p_user_id,
      template_record.id,
      1,
      template_record.target_count,
      window_start,
      window_end,
      p_happened_at
    )
    on conflict (organization_id, user_id, challenge_template_id, window_starts_at)
    do update
    set
      progress_count = public.user_challenge_progress.progress_count + 1,
      last_event_at = excluded.last_event_at
    returning *
    into progress_record;

    if not progress_record.is_completed
      and progress_record.progress_count >= progress_record.target_count
    then
      select *
      into awarded_tx
      from public.award_wallet_points(
        p_organization_id,
        p_user_id,
        'bonus',
        'challenge_bonus',
        template_record.bonus_points,
        p_company_id,
        p_followup_id,
        template_record.id,
        null,
        progress_record.id,
        'challenge_progress',
        format('challenge_bonus:%s:%s:%s', template_record.id, p_user_id, window_start)::text,
        jsonb_build_object(
          'challenge_name', template_record.name,
          'target_metric', template_record.target_metric,
          'window_starts_at', window_start,
          'window_ends_at', window_end
        ),
        p_actor_user_id,
        false
      );

      update public.user_challenge_progress
      set
        is_completed = true,
        completed_at = coalesce(completed_at, p_happened_at),
        bonus_awarded_transaction_id = awarded_tx.transaction_id
      where id = progress_record.id;
    end if;
  end loop;
end;
$$;

create or replace function public.maybe_apply_weekly_conversion_bonus(
  p_organization_id uuid,
  p_user_id uuid,
  p_happened_at timestamptz default now(),
  p_actor_user_id uuid default auth.uid()
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  week_start timestamptz := date_trunc('week', p_happened_at);
  week_end timestamptz := date_trunc('week', p_happened_at) + interval '1 week';
  conversion_count integer := 0;
  configured_points integer := 0;
begin
  select count(*)
  into conversion_count
  from public.wallet_transactions
  where organization_id = p_organization_id
    and user_id = p_user_id
    and action_key = 'lead_converted_won'
    and created_at >= week_start
    and created_at < week_end;

  if conversion_count < 5 then
    return;
  end if;

  select points
  into configured_points
  from public.lead_score_rules
  where organization_id = p_organization_id
    and action_key = 'weekly_conversion_bonus'
    and is_active = true;

  if coalesce(configured_points, 0) <= 0 then
    return;
  end if;

  perform public.award_wallet_points(
    p_organization_id,
    p_user_id,
    'bonus',
    'weekly_conversion_bonus',
    configured_points,
    null,
    null,
    null,
    null,
    null,
    'weekly_window',
    format('weekly_conversion_bonus:%s:%s', p_user_id, week_start)::text,
    jsonb_build_object(
      'week_starts_at', week_start,
      'week_ends_at', week_end,
      'conversion_count', conversion_count
    ),
    p_actor_user_id,
    false
  );
end;
$$;

create or replace function public.apply_scoring_event(
  p_organization_id uuid,
  p_user_id uuid,
  p_action_key text,
  p_company_id uuid default null,
  p_followup_id uuid default null,
  p_source_record_id uuid default null,
  p_source_record_type text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_actor_user_id uuid default auth.uid(),
  p_happened_at timestamptz default now(),
  p_add_to_lead_score boolean default true,
  p_idempotency_key text default null
)
returns table (
  transaction_id uuid,
  points_awarded integer,
  balance_after integer,
  applied boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  configured_points integer := 0;
  tx record;
  normalized_source text;
begin
  if p_idempotency_key is not null and exists (
    select 1
    from public.wallet_transactions
    where organization_id = p_organization_id
      and idempotency_key = p_idempotency_key
  ) then
    return query
    select
      wt.id,
      wt.points_delta,
      wt.balance_after,
      false
    from public.wallet_transactions wt
    where wt.organization_id = p_organization_id
      and wt.idempotency_key = p_idempotency_key;
    return;
  end if;

  if p_action_key = 'lead_source_bonus' then
    normalized_source := public.normalize_lead_source(p_metadata ->> 'lead_source');
    select bonus_points
    into configured_points
    from public.lead_source_score_rules
    where organization_id = p_organization_id
      and lead_source_score_rules.normalized_source = normalized_source
      and is_active = true;
  else
    select points
    into configured_points
    from public.lead_score_rules
    where organization_id = p_organization_id
      and action_key = p_action_key
      and is_active = true;
  end if;

  if coalesce(configured_points, 0) <= 0 then
    return query select null::uuid, 0, 0, false;
    return;
  end if;

  select *
  into tx
  from public.award_wallet_points(
    p_organization_id,
    p_user_id,
    case when p_action_key in ('weekly_conversion_bonus', 'challenge_bonus') then 'bonus' else 'earn' end,
    p_action_key,
    configured_points,
    p_company_id,
    p_followup_id,
    null,
    null,
    p_source_record_id,
    p_source_record_type,
    p_idempotency_key,
    p_metadata,
    p_actor_user_id,
    p_add_to_lead_score
  );

  if p_action_key in ('lead_created', 'lead_qualified', 'lead_converted_won', 'followup_completed', 'lead_referral', 'team_invite_accepted') then
    perform public.update_scoring_streak(p_organization_id, p_user_id, 'lead_activity', p_happened_at);
    perform public.sync_challenge_progress_from_event(
      p_organization_id,
      p_user_id,
      p_action_key,
      p_happened_at,
      p_company_id,
      p_followup_id,
      p_source_record_id,
      p_source_record_type,
      p_metadata,
      p_actor_user_id
    );
  end if;

  if p_action_key = 'lead_converted_won' then
    perform public.maybe_apply_weekly_conversion_bonus(
      p_organization_id,
      p_user_id,
      p_happened_at,
      p_actor_user_id
    );
  end if;

  return query
  select tx.transaction_id, tx.points_delta, tx.balance_after, true;
end;
$$;

create or replace function public.redeem_wallet_reward(
  p_reward_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns table (
  redemption_id uuid,
  transaction_id uuid,
  remaining_balance integer,
  status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  current_org_id uuid := public.current_organization_id();
  reward_record public.rewards_catalog%rowtype;
  redemption_record public.reward_redemptions%rowtype;
  tx record;
  current_balance integer;
  badge_key_value text;
  redemption_status text := 'pending';
begin
  if current_user_id is null or current_org_id is null then
    raise exception 'Authentication and organization are required.';
  end if;

  select *
  into reward_record
  from public.rewards_catalog
  where id = p_reward_id
    and organization_id = current_org_id
    and is_active = true;

  if not found then
    raise exception 'Reward was not found.';
  end if;

  select wallet_balance
  into current_balance
  from public.profiles
  where id = current_user_id
    and organization_id = current_org_id;

  if coalesce(current_balance, 0) < reward_record.cost_points then
    raise exception 'Insufficient wallet balance.';
  end if;

  if reward_record.inventory is not null and reward_record.inventory <= 0 then
    raise exception 'Reward inventory is exhausted.';
  end if;

  insert into public.reward_redemptions (
    organization_id,
    user_id,
    reward_id,
    points_spent,
    status,
    metadata
  )
  values (
    current_org_id,
    current_user_id,
    reward_record.id,
    reward_record.cost_points,
    case when reward_record.fulfillment_mode = 'automatic' then 'fulfilled' else 'pending' end,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning *
  into redemption_record;

  select *
  into tx
  from public.award_wallet_points(
    current_org_id,
    current_user_id,
    'redeem',
    'reward_redeemed',
    reward_record.cost_points * -1,
    null,
    null,
    null,
    reward_record.id,
    redemption_record.id,
    'reward_redemption',
    format('reward_redeemed:%s:%s', current_user_id, redemption_record.id)::text,
    jsonb_build_object(
      'reward_name', reward_record.name,
      'reward_type', reward_record.reward_type
    ) || coalesce(p_metadata, '{}'::jsonb),
    current_user_id,
    false
  );

  if reward_record.inventory is not null then
    update public.rewards_catalog
    set inventory = inventory - 1
    where id = reward_record.id
      and organization_id = current_org_id
      and inventory is not null;
  end if;

  if reward_record.reward_type = 'badge' then
    badge_key_value := coalesce(nullif(reward_record.feature_key, ''), public.slugify(reward_record.name));
    insert into public.user_badges (
      organization_id,
      user_id,
      reward_id,
      badge_key,
      badge_name,
      badge_description,
      metadata,
      awarded_by
    )
    values (
      current_org_id,
      current_user_id,
      reward_record.id,
      badge_key_value,
      reward_record.name,
      reward_record.description,
      reward_record.metadata,
      current_user_id
    )
    on conflict (organization_id, user_id, badge_key) do nothing;
  end if;

  return query
  select redemption_record.id, tx.transaction_id, tx.balance_after, redemption_record.status;
end;
$$;

create or replace function public.get_wallet_leaderboard(
  p_organization_id uuid default public.current_organization_id(),
  p_period text default 'all_time',
  p_limit integer default 10
)
returns table (
  rank bigint,
  user_id uuid,
  full_name text,
  email text,
  avatar_url text,
  wallet_balance integer,
  wallet_lifetime_earned integer,
  period_points integer
)
language sql
stable
security definer
set search_path = public
as $$
  with bounds as (
    select
      case
        when p_period = 'daily' then date_trunc('day', now())
        when p_period = 'weekly' then date_trunc('week', now())
        else null
      end as start_at
  ),
  ranked as (
    select
      p.id as user_id,
      p.full_name,
      p.email,
      p.avatar_url,
      p.wallet_balance,
      p.wallet_lifetime_earned,
      coalesce(sum(
        case
          when b.start_at is null and wt.points_delta > 0 then wt.points_delta
          when b.start_at is not null and wt.created_at >= b.start_at and wt.points_delta > 0 then wt.points_delta
          else 0
        end
      ), 0)::integer as period_points
    from public.profiles p
    cross join bounds b
    left join public.wallet_transactions wt
      on wt.organization_id = p.organization_id
     and wt.user_id = p.id
    where p.organization_id = p_organization_id
      and p.is_active = true
    group by p.id, p.full_name, p.email, p.avatar_url, p.wallet_balance, p.wallet_lifetime_earned
  )
  select
    dense_rank() over (order by ranked.period_points desc, ranked.wallet_balance desc, ranked.email asc) as rank,
    ranked.user_id,
    ranked.full_name,
    ranked.email,
    ranked.avatar_url,
    ranked.wallet_balance,
    ranked.wallet_lifetime_earned,
    ranked.period_points
  from ranked
  where ranked.period_points > 0 or p_period = 'all_time'
  order by rank, ranked.email
  limit greatest(p_limit, 1);
$$;

create or replace function public.get_user_wallet_summary(
  p_user_id uuid default auth.uid()
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with profile_row as (
    select
      p.id,
      p.organization_id,
      p.full_name,
      p.email,
      p.wallet_balance,
      p.wallet_lifetime_earned
    from public.profiles p
    where p.id = coalesce(p_user_id, auth.uid())
      and p.organization_id = public.current_organization_id()
  ),
  recent_transactions as (
    select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) as items
    from (
      select
        wt.id,
        wt.transaction_type,
        wt.action_key,
        wt.points_delta,
        wt.balance_after,
        wt.company_id,
        wt.followup_id,
        wt.reward_id,
        wt.metadata,
        wt.created_at
      from public.wallet_transactions wt
      join profile_row p on p.organization_id = wt.organization_id and p.id = wt.user_id
      order by wt.created_at desc
      limit 20
    ) t
  ),
  active_badges as (
    select coalesce(jsonb_agg(to_jsonb(b) order by b.awarded_at desc), '[]'::jsonb) as items
    from (
      select
        ub.id,
        ub.badge_key,
        ub.badge_name,
        ub.badge_description,
        ub.metadata,
        ub.awarded_at
      from public.user_badges ub
      join profile_row p on p.organization_id = ub.organization_id and p.id = ub.user_id
      order by ub.awarded_at desc
    ) b
  ),
  active_streaks as (
    select coalesce(jsonb_agg(to_jsonb(s) order by s.updated_at desc), '[]'::jsonb) as items
    from (
      select
        us.id,
        us.streak_key,
        us.current_streak,
        us.best_streak,
        us.last_activity_date,
        us.updated_at
      from public.user_streaks us
      join profile_row p on p.organization_id = us.organization_id and p.id = us.user_id
      order by us.updated_at desc
    ) s
  ),
  challenge_progress as (
    select coalesce(jsonb_agg(to_jsonb(cp) order by cp.updated_at desc), '[]'::jsonb) as items
    from (
      select
        ucp.id,
        ucp.challenge_template_id,
        ct.name,
        ct.description,
        ct.cadence,
        ct.target_metric,
        ucp.progress_count,
        ucp.target_count,
        ucp.is_completed,
        ucp.completed_at,
        ucp.window_starts_at,
        ucp.window_ends_at,
        ucp.updated_at
      from public.user_challenge_progress ucp
      join public.challenge_templates ct on ct.id = ucp.challenge_template_id
      join profile_row p on p.organization_id = ucp.organization_id and p.id = ucp.user_id
      order by ucp.updated_at desc
      limit 20
    ) cp
  )
  select jsonb_build_object(
    'user_id', p.id,
    'organization_id', p.organization_id,
    'full_name', p.full_name,
    'email', p.email,
    'wallet_balance', p.wallet_balance,
    'wallet_lifetime_earned', p.wallet_lifetime_earned,
    'recent_transactions', rt.items,
    'badges', ab.items,
    'streaks', st.items,
    'challenge_progress', ch.items
  )
  from profile_row p
  cross join recent_transactions rt
  cross join active_badges ab
  cross join active_streaks st
  cross join challenge_progress ch;
$$;

create or replace function public.seed_lead_scoring_defaults(target_organization_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.lead_score_rules (
    organization_id,
    action_key,
    name,
    description,
    points,
    is_active,
    rule_scope
  )
  values
    (target_organization_id, 'lead_created', 'Lead creation', 'Awarded when a user creates a new lead.', 10, true, '{}'::jsonb),
    (target_organization_id, 'lead_qualified', 'Lead qualification', 'Awarded when a user advances a lead forward in the pipeline.', 5, true, jsonb_build_object('mode', 'per_stage_transition')),
    (target_organization_id, 'lead_converted_won', 'Lead conversion', 'Awarded when a user moves a lead into a won stage.', 50, true, '{}'::jsonb),
    (target_organization_id, 'followup_completed', 'Follow-up completion', 'Awarded when a follow-up is marked completed.', 5, true, '{}'::jsonb),
    (target_organization_id, 'weekly_conversion_bonus', 'Weekly conversion bonus', 'Bonus awarded after 5 won conversions in a week.', 50, true, jsonb_build_object('threshold', 5)),
    (target_organization_id, 'lead_referral', 'Lead referral reward', 'Awarded to the referring user when a referred lead is created.', 15, true, '{}'::jsonb),
    (target_organization_id, 'team_invite_accepted', 'Team invitation reward', 'Awarded when an invited teammate accepts a team invitation.', 25, true, '{}'::jsonb)
  on conflict (organization_id, action_key) do update
  set
    name = excluded.name,
    description = excluded.description,
    points = excluded.points,
    is_active = excluded.is_active,
    rule_scope = excluded.rule_scope;

  insert into public.lead_source_score_rules (
    organization_id,
    source_name,
    normalized_source,
    bonus_points,
    is_active
  )
  values
    (target_organization_id, 'LinkedIn', public.normalize_lead_source('LinkedIn'), 20, true),
    (target_organization_id, 'Website', public.normalize_lead_source('Website'), 10, true)
  on conflict (organization_id, normalized_source) do update
  set
    source_name = excluded.source_name,
    bonus_points = excluded.bonus_points,
    is_active = excluded.is_active;

  insert into public.challenge_templates (
    organization_id,
    name,
    description,
    cadence,
    target_metric,
    target_count,
    bonus_points,
    is_active,
    config
  )
  values
    (target_organization_id, 'Daily Follow-up Focus', 'Complete three follow-ups today for a bonus.', 'daily', 'followup_completed', 3, 15, true, '{}'::jsonb),
    (target_organization_id, 'Weekly Closer', 'Convert five leads to won this week for a bonus.', 'weekly', 'lead_converted_won', 5, 50, true, '{}'::jsonb)
  on conflict do nothing;

  insert into public.rewards_catalog (
    organization_id,
    name,
    description,
    reward_type,
    cost_points,
    feature_key,
    inventory,
    fulfillment_mode,
    is_active,
    metadata
  )
  values
    (target_organization_id, 'Top Seller', 'Badge for consistent high performers.', 'badge', 100, 'top-seller', null, 'automatic', true, jsonb_build_object('icon', 'trophy')),
    (target_organization_id, 'Advanced Analytics Unlock', 'Premium analytics access for your profile.', 'premium_feature', 300, 'advanced_analytics', null, 'manual', true, '{}'::jsonb),
    (target_organization_id, 'Subscription Discount', 'Admin-fulfilled subscription discount reward.', 'discount', 500, 'subscription_discount', 25, 'manual', true, '{}'::jsonb)
  on conflict do nothing;
end;
$$;

create or replace function public.seed_lead_scoring_defaults_after_organization()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.seed_lead_scoring_defaults(new.id);
  return new;
end;
$$;

drop trigger if exists seed_lead_scoring_defaults_after_organization on public.organizations;
create trigger seed_lead_scoring_defaults_after_organization
after insert on public.organizations
for each row execute function public.seed_lead_scoring_defaults_after_organization();

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
        'subscription.view', 'subscription.manage',
        'scoring.view', 'scoring.manage', 'rewards.manage', 'leaderboard.view'
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
        'team.view',
        'scoring.view', 'leaderboard.view'
      ]
      when 'sales-executive' then array[
        'dashboard.view',
        'companies.view', 'companies.create', 'companies.update', 'companies.archive',
        'contacts.view', 'contacts.create', 'contacts.update', 'contacts.archive',
        'meetings.view', 'meetings.create', 'meetings.update',
        'followups.view', 'followups.create', 'followups.update', 'followups.complete', 'followups.cancel',
        'documents.view', 'documents.upload', 'documents.update', 'documents.download',
        'leaderboard.view'
      ]
      when 'support-user' then array[
        'dashboard.view',
        'companies.view',
        'contacts.view',
        'meetings.view',
        'followups.view', 'followups.create', 'followups.update', 'followups.complete', 'followups.cancel',
        'documents.view', 'documents.upload', 'documents.update', 'documents.download', 'documents.archive',
        'help_requests.view', 'help_requests.create', 'help_requests.assign', 'help_requests.resolve', 'help_requests.reject', 'help_requests.archive',
        'leaderboard.view'
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
        'subscription.view',
        'leaderboard.view'
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

insert into public.permissions (key, name, description)
values
  ('scoring.view', 'View scoring data', 'View wallet balances, scoring activity, and challenge progress.'),
  ('scoring.manage', 'Manage scoring', 'Manage scoring rules, challenges, and manual wallet adjustments.'),
  ('rewards.manage', 'Manage rewards', 'Manage rewards catalog and reward redemption fulfillment.'),
  ('leaderboard.view', 'View leaderboard', 'View leaderboard standings and rankings.')
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description;

alter table public.lead_score_rules enable row level security;
alter table public.lead_source_score_rules enable row level security;
alter table public.challenge_templates enable row level security;
alter table public.rewards_catalog enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.user_challenge_progress enable row level security;
alter table public.user_streaks enable row level security;
alter table public.reward_redemptions enable row level security;
alter table public.user_badges enable row level security;
alter table public.scoring_activity_logs enable row level security;

drop policy if exists "Organization members can read lead score rules" on public.lead_score_rules;
create policy "Organization members can read lead score rules"
on public.lead_score_rules for select
to authenticated
using (public.is_organization_member(organization_id));

drop policy if exists "Organization admins can manage lead score rules" on public.lead_score_rules;
create policy "Organization admins can manage lead score rules"
on public.lead_score_rules for all
to authenticated
using (public.is_organization_admin(organization_id))
with check (public.is_organization_admin(organization_id));

drop policy if exists "Organization members can read lead source score rules" on public.lead_source_score_rules;
create policy "Organization members can read lead source score rules"
on public.lead_source_score_rules for select
to authenticated
using (public.is_organization_member(organization_id));

drop policy if exists "Organization admins can manage lead source score rules" on public.lead_source_score_rules;
create policy "Organization admins can manage lead source score rules"
on public.lead_source_score_rules for all
to authenticated
using (public.is_organization_admin(organization_id))
with check (public.is_organization_admin(organization_id));

drop policy if exists "Organization members can read challenge templates" on public.challenge_templates;
create policy "Organization members can read challenge templates"
on public.challenge_templates for select
to authenticated
using (public.is_organization_member(organization_id));

drop policy if exists "Organization admins can manage challenge templates" on public.challenge_templates;
create policy "Organization admins can manage challenge templates"
on public.challenge_templates for all
to authenticated
using (public.is_organization_admin(organization_id))
with check (public.is_organization_admin(organization_id));

drop policy if exists "Organization members can read rewards catalog" on public.rewards_catalog;
create policy "Organization members can read rewards catalog"
on public.rewards_catalog for select
to authenticated
using (public.is_organization_member(organization_id));

drop policy if exists "Organization admins can manage rewards catalog" on public.rewards_catalog;
create policy "Organization admins can manage rewards catalog"
on public.rewards_catalog for all
to authenticated
using (public.is_organization_admin(organization_id))
with check (public.is_organization_admin(organization_id));

drop policy if exists "Users can read their wallet transactions" on public.wallet_transactions;
create policy "Users can read their wallet transactions"
on public.wallet_transactions for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_organization_admin(organization_id)
);

drop policy if exists "Users can read their challenge progress" on public.user_challenge_progress;
create policy "Users can read their challenge progress"
on public.user_challenge_progress for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_organization_admin(organization_id)
);

drop policy if exists "Users can read their streaks" on public.user_streaks;
create policy "Users can read their streaks"
on public.user_streaks for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_organization_admin(organization_id)
);

drop policy if exists "Users can read their reward redemptions" on public.reward_redemptions;
create policy "Users can read their reward redemptions"
on public.reward_redemptions for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_organization_admin(organization_id)
);

drop policy if exists "Organization admins can manage reward redemptions" on public.reward_redemptions;
create policy "Organization admins can manage reward redemptions"
on public.reward_redemptions for update
to authenticated
using (public.is_organization_admin(organization_id))
with check (public.is_organization_admin(organization_id));

drop policy if exists "Organization members can read user badges" on public.user_badges;
create policy "Organization members can read user badges"
on public.user_badges for select
to authenticated
using (public.is_organization_member(organization_id));

drop policy if exists "Organization admins can manage user badges" on public.user_badges;
create policy "Organization admins can manage user badges"
on public.user_badges for all
to authenticated
using (public.is_organization_admin(organization_id))
with check (public.is_organization_admin(organization_id));

drop policy if exists "Organization members can read scoring activity logs" on public.scoring_activity_logs;
create policy "Organization members can read scoring activity logs"
on public.scoring_activity_logs for select
to authenticated
using (public.is_organization_member(organization_id));

grant select on public.lead_score_rules to authenticated;
grant select on public.lead_source_score_rules to authenticated;
grant select on public.challenge_templates to authenticated;
grant select on public.rewards_catalog to authenticated;
grant select on public.wallet_transactions to authenticated;
grant select on public.user_challenge_progress to authenticated;
grant select on public.user_streaks to authenticated;
grant select on public.reward_redemptions to authenticated;
grant select on public.user_badges to authenticated;
grant select on public.scoring_activity_logs to authenticated;

grant insert, update, delete on public.lead_score_rules to authenticated;
grant insert, update, delete on public.lead_source_score_rules to authenticated;
grant insert, update, delete on public.challenge_templates to authenticated;
grant insert, update, delete on public.rewards_catalog to authenticated;
grant update on public.reward_redemptions to authenticated;
grant insert, update, delete on public.user_badges to authenticated;

grant execute on function public.update_scoring_streak(uuid, uuid, text, timestamptz) to authenticated;
grant execute on function public.award_wallet_points(uuid, uuid, text, text, integer, uuid, uuid, uuid, uuid, uuid, text, text, jsonb, uuid, boolean) to authenticated;
grant execute on function public.sync_challenge_progress_from_event(uuid, uuid, text, timestamptz, uuid, uuid, uuid, text, jsonb, uuid) to authenticated;
grant execute on function public.maybe_apply_weekly_conversion_bonus(uuid, uuid, timestamptz, uuid) to authenticated;
grant execute on function public.apply_scoring_event(uuid, uuid, text, uuid, uuid, uuid, text, jsonb, uuid, timestamptz, boolean, text) to authenticated;
grant execute on function public.redeem_wallet_reward(uuid, jsonb) to authenticated;
grant execute on function public.get_wallet_leaderboard(uuid, text, integer) to authenticated;
grant execute on function public.get_user_wallet_summary(uuid) to authenticated;
grant execute on function public.seed_lead_scoring_defaults(uuid) to authenticated;
grant execute on function public.normalize_lead_source(text) to authenticated;
grant execute on function public.get_score_action_title(text) to authenticated;

select public.seed_lead_scoring_defaults(id) from public.organizations;
select public.sync_default_role_permissions(id) from public.organizations;
