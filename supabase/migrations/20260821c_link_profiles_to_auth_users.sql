-- Make deleting an account actually delete the account.
--
-- public.users.id held an auth user's id but had no foreign key to auth.users,
-- so the two could drift apart. That is what made "Delete Account" in the app
-- destructive without being effective: it deleted the profile row, the auth
-- record survived, the same password still signed in, and handle_new_auth_user
-- only fires for NEW auth users — so no profile was ever recreated. The account
-- came back permanently broken.
--
-- With this constraint, deleting the auth user removes the profile, and the
-- existing cascades take routes, reviews and saved routes with it.

-- Backfill first: six auth users predate the trigger and have no profile row.
-- They are in exactly the broken state described above, and the constraint does
-- not require them, but leaving them means six accounts that cannot use Settings.
insert into public.users (id, full_name, username, city_id, registration_date)
select a.id,
       coalesce(a.raw_user_meta_data->>'full_name', split_part(a.email, '@', 1)),
       coalesce(a.raw_user_meta_data->>'username',  split_part(a.email, '@', 1)),
       1,
       coalesce(a.created_at, now())
from auth.users a
where not exists (select 1 from public.users u where u.id = a.id)
on conflict (id) do nothing;

alter table public.users
  add constraint users_id_fkey
  foreign key (id) references auth.users (id) on delete cascade;
