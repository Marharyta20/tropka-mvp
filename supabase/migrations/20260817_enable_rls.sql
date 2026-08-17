-- ============================================================================
-- Tropka — enable Row Level Security
-- Applied 2026-08-17.
--
-- Run as a whole in Supabase → SQL Editor. It is one transaction: if anything
-- fails, everything rolls back and the database stays as it was.
--
-- Access model:
--   reference data (places, cities, categories, districts, tips, tip_pages)
--       — readable by any signed-in user, writable only via service_role
--         (dashboard, import scripts)
--   routes, route_stops
--       — readable by any signed-in user, writable only by the route author
--   reviews, saved_routes, users
--       — each user sees and edits only their own rows
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. Aggregation triggers. This step is mandatory, not cosmetic.
--
-- update_route_rating fires on reviews and writes into routes.rating. Without
-- SECURITY DEFINER it runs as whoever inserted the review and hits the
-- author-only UPDATE policy. Result: reviewing someone else's route fails with
-- a permission error. This is exactly where people give up and turn RLS off.
--
-- SET search_path also clears four WARNings from the Supabase linter.
-- ----------------------------------------------------------------------------

create or replace function public.update_route_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_route_id uuid;
begin
  target_route_id := coalesce(new.route_id, old.route_id);

  update public.routes r
  set rating = coalesce((
        select round(avg(rv.rating)::numeric, 2)
        from public.reviews rv
        where rv.route_id = target_route_id
      ), 0),
      review_count = (
        select count(*)
        from public.reviews rv
        where rv.route_id = target_route_id
      )
  where r.id = target_route_id;

  return coalesce(new, old);
end;
$$;

create or replace function public.update_route_duration()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_route_id uuid;
begin
  target_route_id := coalesce(new.route_id, old.route_id);

  update public.routes r
  set duration = coalesce((
        select sum(rs.time_spent)
        from public.route_stops rs
        where rs.route_id = target_route_id
      ), 0)
  where r.id = target_route_id;

  return coalesce(new, old);
end;
$$;

alter function public.handle_new_auth_user() set search_path = public;
alter function public.set_updated_at()      set search_path = public;

-- These are trigger functions and have no business being exposed as
-- /rest/v1/rpc/... endpoints. anon and authenticated inherit EXECUTE from
-- PUBLIC, so revoking from those two roles alone does nothing — revoke from
-- PUBLIC as well.
revoke execute on function public.handle_new_auth_user()  from public, anon, authenticated;
revoke execute on function public.update_route_rating()   from public, anon, authenticated;
revoke execute on function public.update_route_duration() from public, anon, authenticated;
revoke execute on function public.set_updated_at()        from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2. Enable RLS on every table
-- ----------------------------------------------------------------------------

alter table public.users        enable row level security;
alter table public.routes       enable row level security;
alter table public.route_stops  enable row level security;
alter table public.saved_routes enable row level security;
alter table public.reviews      enable row level security;
alter table public.places       enable row level security;
alter table public.cities       enable row level security;
alter table public.categories   enable row level security;
alter table public.districts    enable row level security;
alter table public.tips         enable row level security;
alter table public.tip_pages    enable row level security;

-- ----------------------------------------------------------------------------
-- 3. Reference data — read only, for signed-in users
--
-- No insert/update/delete policies on purpose: what does not exist is denied.
-- Import scripts must use the service_role key, which bypasses RLS.
-- ----------------------------------------------------------------------------

create policy "places readable"     on public.places     for select to authenticated using (true);
create policy "cities readable"     on public.cities     for select to authenticated using (true);
create policy "categories readable" on public.categories for select to authenticated using (true);
create policy "districts readable"  on public.districts  for select to authenticated using (true);
create policy "tips readable"       on public.tips       for select to authenticated using (true);
create policy "tip_pages readable"  on public.tip_pages  for select to authenticated using (true);

-- ----------------------------------------------------------------------------
-- 4. Routes — readable by all, writable by the author
--
-- Side effect: this closes a hole in RouteEditorService.updateRoute, which
-- updates by id without checking authorship — meaning any signed-in user could
-- overwrite someone else's route. These policies stop that.
-- ----------------------------------------------------------------------------

create policy "routes readable" on public.routes
  for select to authenticated using (true);

create policy "routes insert own" on public.routes
  for insert to authenticated with check (author_uid = auth.uid());

create policy "routes update own" on public.routes
  for update to authenticated using (author_uid = auth.uid())
                                with check (author_uid = auth.uid());

create policy "routes delete own" on public.routes
  for delete to authenticated using (author_uid = auth.uid());

-- ----------------------------------------------------------------------------
-- 5. Stops — inherit the permissions of their parent route
-- ----------------------------------------------------------------------------

create policy "route_stops readable" on public.route_stops
  for select to authenticated using (true);

create policy "route_stops insert via own route" on public.route_stops
  for insert to authenticated with check (
    exists (select 1 from public.routes r
            where r.id = route_stops.route_id and r.author_uid = auth.uid())
  );

create policy "route_stops update via own route" on public.route_stops
  for update to authenticated using (
    exists (select 1 from public.routes r
            where r.id = route_stops.route_id and r.author_uid = auth.uid())
  );

create policy "route_stops delete via own route" on public.route_stops
  for delete to authenticated using (
    exists (select 1 from public.routes r
            where r.id = route_stops.route_id and r.author_uid = auth.uid())
  );

-- ----------------------------------------------------------------------------
-- 6. Reviews — readable by every signed-in user, writable by the author
--
-- Opened up by decision on 2026-08-17: other people's reviews should be visible
-- on a route page. Note: the author's name cannot be displayed yet — see the
-- follow-up migration 20260817b, which frees public.users for that.
-- ----------------------------------------------------------------------------

create policy "reviews readable" on public.reviews
  for select to authenticated using (true);

create policy "reviews insert own" on public.reviews
  for insert to authenticated with check (user_id = auth.uid());

create policy "reviews update own" on public.reviews
  for update to authenticated using (user_id = auth.uid())
                                with check (user_id = auth.uid());

create policy "reviews delete own" on public.reviews
  for delete to authenticated using (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 7. Saved routes — strictly private
-- ----------------------------------------------------------------------------

create policy "saved_routes select own" on public.saved_routes
  for select to authenticated using (user_id = auth.uid());

create policy "saved_routes insert own" on public.saved_routes
  for insert to authenticated with check (user_id = auth.uid());

create policy "saved_routes update own" on public.saved_routes
  for update to authenticated using (user_id = auth.uid())
                                with check (user_id = auth.uid());

create policy "saved_routes delete own" on public.saved_routes
  for delete to authenticated using (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 8. Profiles — own row only
--
-- The row itself is created by the handle_new_auth_user trigger
-- (SECURITY DEFINER); the insert policy is needed for the upsert in
-- AuthService.signUp.
--
-- Superseded by 20260817b: once email left this table, select was opened up.
-- ----------------------------------------------------------------------------

create policy "users select own" on public.users
  for select to authenticated using (id = auth.uid());

create policy "users insert own" on public.users
  for insert to authenticated with check (id = auth.uid());

create policy "users update own" on public.users
  for update to authenticated using (id = auth.uid())
                                with check (id = auth.uid());

create policy "users delete own" on public.users
  for delete to authenticated using (id = auth.uid());

commit;

-- ============================================================================
-- Post-run check: both queries should return nothing.
--
--   select tablename from pg_tables
--   where schemaname = 'public' and rowsecurity = false;
--
--   select tablename from pg_tables t
--   where schemaname = 'public'
--     and not exists (select 1 from pg_policies p
--                     where p.schemaname = 'public' and p.tablename = t.tablename);
-- ============================================================================
