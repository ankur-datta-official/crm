-- Migration 012: Notifications, Search, and UX Polish
-- Sprint 12

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  message text not null,
  link text,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_org_user_read_created_idx
  on public.notifications (organization_id, user_id, is_read, created_at desc);

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "Users can view their notifications" on public.notifications;
create policy "Users can view their notifications"
on public.notifications for select
to authenticated
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.organization_id = notifications.organization_id
      and profile.is_active = true
  )
);

drop policy if exists "Users can update their notifications" on public.notifications;
create policy "Users can update their notifications"
on public.notifications for update
to authenticated
using (
  user_id = auth.uid()
  and exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.organization_id = notifications.organization_id
      and profile.is_active = true
  )
)
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.organization_id = notifications.organization_id
      and profile.is_active = true
  )
);

drop policy if exists "Organization users can create notifications in their workspace" on public.notifications;
create policy "Organization users can create notifications in their workspace"
on public.notifications for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles actor
    join public.profiles recipient
      on recipient.id = notifications.user_id
    where actor.id = auth.uid()
      and actor.organization_id = notifications.organization_id
      and recipient.organization_id = notifications.organization_id
      and actor.is_active = true
  )
);

grant select, insert, update on public.notifications to authenticated;
