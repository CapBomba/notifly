-- ============================================================
-- NotiFly — Initial Supabase Schema
-- ============================================================
-- Run this migration in your Supabase SQL editor or with the
-- Supabase CLI: supabase db push
-- ============================================================

-- Enable the pgcrypto extension for gen_random_uuid()
create extension if not exists "pgcrypto";

-- ============================================================
-- 1. Profiles
-- ============================================================
-- Mirrors auth.users so that RLS policies can reference user
-- metadata without exposing the auth schema directly.

create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text not null,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Auto-create a profile on new user sign-up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- 2. Notifications
-- ============================================================

create type public.notification_type as enum (
  'generic',
  'message',
  'announcement',
  'task_update'
);

create type public.notification_priority as enum (
  'normal',   -- 0
  'high',     -- 1
  'urgent'    -- 2
);

create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  title       text not null,
  body        text not null,
  type        public.notification_type not null default 'generic',
  payload     text,                          -- arbitrary JSON string for deep-links
  is_read     boolean not null default false,
  priority    public.notification_priority not null default 'normal',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists notifications_user_id_created_at_idx
  on public.notifications (user_id, created_at desc);

create index if not exists notifications_user_id_is_read_idx
  on public.notifications (user_id, is_read)
  where is_read = false;

-- ============================================================
-- 3. Notification Outbox
-- ============================================================
-- Server-side outbox for durable async processing.
-- Edge Functions or workers poll this table.

create type public.outbox_status as enum (
  'pending',
  'processing',
  'processed',
  'failed'
);

create table if not exists public.notification_outbox (
  id            uuid primary key default gen_random_uuid(),
  event_type    text not null,
  payload       jsonb not null default '{}',
  status        public.outbox_status not null default 'pending',
  attempt_count integer not null default 0,
  last_error    text,
  created_at    timestamptz not null default now(),
  next_retry_at timestamptz not null default now()
);

create index if not exists outbox_status_next_retry_idx
  on public.notification_outbox (status, next_retry_at)
  where status = 'pending';

-- ============================================================
-- 4. Notification Preferences
-- ============================================================

create table if not exists public.notification_preferences (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  key         text not null,
  value       text not null,
  updated_at  timestamptz not null default now(),
  primary key (user_id, key)
);

-- ============================================================
-- 5. Announcements
-- ============================================================
-- Admin-broadcast messages that fan out to all users (or a
-- subset) via an Edge Function / trigger.

create table if not exists public.announcements (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid references public.profiles (id),
  title       text not null,
  body        text not null,
  priority    public.notification_priority not null default 'normal',
  target_all  boolean not null default true,
  created_at  timestamptz not null default now(),
  published_at timestamptz
);

-- ============================================================
-- 6. Row Level Security
-- ============================================================

-- profiles
alter table public.profiles enable row level security;

create policy "Users can read their own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- notifications
alter table public.notifications enable row level security;

create policy "Users can read their own notifications"
  on public.notifications for select
  using (auth.uid() = user_id);

create policy "Users can update their own notifications"
  on public.notifications for update
  using (auth.uid() = user_id);

create policy "Users can delete their own notifications"
  on public.notifications for delete
  using (auth.uid() = user_id);

-- Service role (Edge Functions) can insert notifications for any user
create policy "Service role can insert notifications"
  on public.notifications for insert
  with check (true);   -- restrict further via service role key in Edge Functions

-- notification_outbox — Edge Functions / service role only
alter table public.notification_outbox enable row level security;
-- No client-level policies; accessed exclusively via service role.

-- notification_preferences
alter table public.notification_preferences enable row level security;

create policy "Users can read their own preferences"
  on public.notification_preferences for select
  using (auth.uid() = user_id);

create policy "Users can upsert their own preferences"
  on public.notification_preferences for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own preferences"
  on public.notification_preferences for update
  using (auth.uid() = user_id);

-- announcements — publicly readable
alter table public.announcements enable row level security;

create policy "Announcements are publicly readable"
  on public.announcements for select
  using (published_at is not null and published_at <= now());

-- ============================================================
-- 7. Realtime publication
-- ============================================================

alter publication supabase_realtime add table public.notifications;

-- ============================================================
-- 8. Utility functions
-- ============================================================

-- Mark a notification as read and record the timestamp
create or replace function public.mark_notification_read(p_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.notifications
  set is_read = true, updated_at = now()
  where id = p_id
    and user_id = auth.uid();
end;
$$;

-- Mark all notifications as read for the calling user
create or replace function public.mark_all_notifications_read()
returns void
language plpgsql
security definer
as $$
begin
  update public.notifications
  set is_read = true, updated_at = now()
  where user_id = auth.uid()
    and is_read = false;
end;
$$;
