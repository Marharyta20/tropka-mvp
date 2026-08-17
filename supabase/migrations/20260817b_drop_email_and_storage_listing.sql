-- ============================================================================
-- Tropka — move email out of public.users, stop bucket listing
-- Applied 2026-08-17, after 20260817_enable_rls.sql
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. The profile-creation trigger no longer copies email.
--    IMPORTANT: this must come BEFORE the drop column below — otherwise the
--    trigger breaks on the very next sign-up.
-- ----------------------------------------------------------------------------

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, full_name, username, city_id, registration_date)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'username',  split_part(new.email, '@', 1)),
    1,
    now()
  )
  on conflict (id) do nothing;
  return new;
end; $$;

revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2. Drop email. Verified before removing: all 5 rows of public.users.email
--    matched auth.users.email exactly, so no data is lost — the source of truth
--    stays in auth.users. Nothing in the app ever read email from this table.
-- ----------------------------------------------------------------------------

alter table public.users drop column email;

-- ----------------------------------------------------------------------------
-- 3. The profile now holds nothing private, so open it for reading.
--    This is what makes it possible to show the author of someone else's review.
-- ----------------------------------------------------------------------------

drop policy "users select own" on public.users;

create policy "users readable" on public.users
  for select to authenticated using (true);

-- ----------------------------------------------------------------------------
-- 4. Storage: disallow listing bucket contents.
--
--    The buckets are marked public, so fetching a file by a known URL bypasses
--    RLS and keeps working. These SELECT policies granted something extra: the
--    right to list, i.e. to enumerate and download a whole bucket without
--    knowing any filenames. The app does not need it — StorageService only
--    uploads and builds public URLs, it never calls list().
-- ----------------------------------------------------------------------------

drop policy "Public read avatars" on storage.objects;
drop policy "Public read places"  on storage.objects;
drop policy "Public read routes"  on storage.objects;
drop policy "Public read tips"    on storage.objects;

commit;

-- ============================================================================
-- Companion code change: Tropka/Services/AuthService.swift — the email field
-- was removed from struct UserInsert.
--
-- SEPARATE ISSUE, NOT PART OF THIS MIGRATION:
-- StorageService.swift uploaded to a bucket named "tropka-media", while the
-- project only has avatars / places / routes / tips. Route cover uploads were
-- failing. Fixed in code by introducing a StorageBucket enum.
-- ============================================================================
