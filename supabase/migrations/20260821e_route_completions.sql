-- "I walked this route".
--
-- The schema had no notion of a route being finished, only of it being
-- bookmarked. That left the app with no reason to be opened on the street, no
-- honest moment to ask for a review (the review control was gated on the
-- bookmark, so somebody who walked a route without saving it could not review
-- it), and no engagement number worth reading.

create table if not exists public.route_completions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users(id)  on delete cascade,
  route_id     uuid not null references public.routes(id) on delete cascade,
  completed_at timestamptz not null default now(),
  unique (user_id, route_id)
);

create index if not exists route_completions_route_id_idx
  on public.route_completions (route_id);

alter table public.route_completions enable row level security;

-- A completion is private: you can see, add and remove your own, nobody else's.
-- The public number lives on routes.completed_count instead, kept by the trigger
-- below, so social proof needs no access to who walked what.
create policy "own completions readable" on public.route_completions
  for select to authenticated using ((select auth.uid()) = user_id);

create policy "own completions insertable" on public.route_completions
  for insert to authenticated with check ((select auth.uid()) = user_id);

create policy "own completions deletable" on public.route_completions
  for delete to authenticated using ((select auth.uid()) = user_id);

alter table public.routes
  add column if not exists completed_count integer not null default 0;

-- SECURITY DEFINER because the walker is almost never the route's author, and
-- the routes update policy is author-only. The function touches exactly one
-- column of one row, identified by the completion being written.
create or replace function public.sync_route_completed_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.routes
       set completed_count = completed_count + 1
     where id = new.route_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.routes
       set completed_count = greatest(0, completed_count - 1)
     where id = old.route_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists route_completions_count on public.route_completions;
create trigger route_completions_count
after insert or delete on public.route_completions
for each row execute function public.sync_route_completed_count();
