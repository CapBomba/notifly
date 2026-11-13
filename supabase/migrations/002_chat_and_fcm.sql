-- ============================================================
-- NotiFly — Chat + FCM Token Schema
-- ============================================================

-- ============================================================
-- 1. FCM device tokens
-- ============================================================

create table if not exists public.fcm_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  token       text not null,
  platform    text not null default 'android', -- 'android' | 'ios'
  updated_at  timestamptz not null default now(),
  unique (user_id, token)
);

alter table public.fcm_tokens enable row level security;

create policy "Users manage their own tokens"
  on public.fcm_tokens
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================
-- 2. Conversations (1-on-1 direct messages)
-- ============================================================

create table if not exists public.conversations (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now()
);

alter table public.conversations enable row level security;

-- Users can only see conversations they are members of
create policy "Members can read conversations"
  on public.conversations for select
  using (
    exists (
      select 1 from public.conversation_members cm
      where cm.conversation_id = id
        and cm.user_id = auth.uid()
    )
  );

-- ============================================================
-- 3. Conversation members
-- ============================================================

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id         uuid not null references public.profiles (id) on delete cascade,
  joined_at       timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

alter table public.conversation_members enable row level security;

create policy "Members can read membership"
  on public.conversation_members for select
  using (auth.uid() = user_id);

create policy "Service role inserts membership"
  on public.conversation_members for insert
  with check (true);

-- ============================================================
-- 4. Messages
-- ============================================================

create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id       uuid not null references public.profiles (id) on delete cascade,
  content         text not null check (char_length(content) > 0 and char_length(content) <= 4000),
  created_at      timestamptz not null default now()
);

create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at desc);

alter table public.messages enable row level security;

-- A user can read messages if they are a member of the conversation
create policy "Members read messages"
  on public.messages for select
  using (
    exists (
      select 1 from public.conversation_members cm
      where cm.conversation_id = messages.conversation_id
        and cm.user_id = auth.uid()
    )
  );

-- A user can send messages to conversations they belong to
create policy "Members send messages"
  on public.messages for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.conversation_members cm
      where cm.conversation_id = messages.conversation_id
        and cm.user_id = auth.uid()
    )
  );

-- ============================================================
-- 5. Realtime publications
-- ============================================================

alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.conversations;

-- ============================================================
-- 6. get_or_create_conversation RPC
-- ============================================================
-- Returns the existing conversation id between two users, or
-- creates a new one and adds both as members.

create or replace function public.get_or_create_conversation(
  user_a uuid,
  user_b uuid
)
returns uuid
language plpgsql
security definer
as $$
declare
  conv_id uuid;
begin
  -- Find existing 1-on-1 conversation shared by both users
  select cm1.conversation_id into conv_id
  from public.conversation_members cm1
  join public.conversation_members cm2
    on cm1.conversation_id = cm2.conversation_id
  where cm1.user_id = user_a
    and cm2.user_id = user_b
  limit 1;

  if conv_id is not null then
    return conv_id;
  end if;

  -- Create new conversation
  insert into public.conversations default values
  returning id into conv_id;

  -- Add both members
  insert into public.conversation_members (conversation_id, user_id)
  values (conv_id, user_a), (conv_id, user_b);

  return conv_id;
end;
$$;

-- ============================================================
-- 7. get_conversation_recipient helper
-- ============================================================
-- Returns the other user's profile for a given conversation.

create or replace function public.get_conversation_recipient(
  p_conversation_id uuid,
  p_current_user_id uuid
)
returns table (
  user_id     uuid,
  display_name text,
  email       text,
  avatar_url  text
)
language sql
security definer
as $$
  select
    p.id,
    p.display_name,
    p.email,
    p.avatar_url
  from public.conversation_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.conversation_id = p_conversation_id
    and cm.user_id <> p_current_user_id
  limit 1;
$$;

-- ============================================================
-- 8. Update handle_new_user to handle Google sign-ins
-- ============================================================
-- Google OAuth users have their name/avatar in raw_user_meta_data

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(new.email, '@', 1)
    ),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do update
    set
      display_name = coalesce(
        excluded.display_name,
        profiles.display_name
      ),
      avatar_url = coalesce(
        excluded.avatar_url,
        profiles.avatar_url
      ),
      updated_at = now();
  return new;
end;
$$;
