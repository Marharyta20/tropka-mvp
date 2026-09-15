-- Where to send a push.
--
-- One row per device, not per user: a person with a phone and an iPad has two
-- tokens and expects the notification on both. APNs also issues a new token when
-- the OS is reinstalled or the app is restored from a backup, so a row is a
-- claim about a device *right now* — `last_seen_at` is what lets the sender stop
-- writing to addresses nobody has confirmed in months.
--
-- Apple is explicit that tokens must never be cached locally; the app asks the
-- system for one on every launch and upserts it here.

create table if not exists public.device_tokens (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users(id) on delete cascade,
  token        text not null,
  platform     text not null default 'ios',
  environment  text not null default 'production',
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  unique (token)
);

create index if not exists device_tokens_user_id_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- A device token is an address for one person's phone. Nobody reads anybody
-- else's; the sender runs with the service role and bypasses these.
create policy "own tokens readable" on public.device_tokens
  for select to authenticated using ((select auth.uid()) = user_id);

create policy "own tokens insertable" on public.device_tokens
  for insert to authenticated with check ((select auth.uid()) = user_id);

create policy "own tokens updatable" on public.device_tokens
  for update to authenticated using ((select auth.uid()) = user_id);

create policy "own tokens deletable" on public.device_tokens
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Whether the person wants to be written to at all. Separate from the OS
-- permission: iOS knows if the app *may* send, this knows if the user *asked*
-- to be told. Revoking here must work without going to Settings.
alter table public.users
  add column if not exists notifications_enabled boolean not null default false;

comment on column public.users.notifications_enabled is
  'The in-app switch. The OS permission is necessary but not sufficient — this is the one the user can turn off inside Tropka.';
