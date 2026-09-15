-- What a new account knows about itself.
--
-- Sign-up asks for a name, an email and a password, and then invents a username
-- like "user6246" and leaves the avatar empty — which is why a fresh profile
-- looks like a form somebody abandoned. These two columns back a short setup
-- step that fills in what the profile actually shows.
--
-- Interests are stored as category ids rather than free text so they can be used
-- rather than admired: they order the category tiles on Explore and the filter
-- chips on the map. Deliberately nothing more — with five routes in the
-- catalogue, personalising route recommendations would be a promise the data
-- cannot keep.

alter table public.users
  add column if not exists interests   integer[],
  add column if not exists onboarded_at timestamptz;

comment on column public.users.interests is
  'public.categories.id values the user picked. Used for ordering, never for filtering things away.';
comment on column public.users.onboarded_at is
  'When the setup step was completed. Null means a new account that has not been through it.';

-- Existing accounts are treated as done. Interrupting somebody who has been
-- using the app for two months to ask them to pick an avatar is a worse
-- introduction than not asking at all.
update public.users
   set onboarded_at = coalesce(registration_date, now())
 where onboarded_at is null;
