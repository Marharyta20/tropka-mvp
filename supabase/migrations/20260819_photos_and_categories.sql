-- Two problems, one file.
--
-- 1. Photos. Every photo link in the catalogue came from Google Places and they
--    expire after a few weeks — 2189 of 2338 were returning 403, so the app showed
--    grey boxes everywhere. Wikimedia images do not expire and may be stored, as
--    long as author and licence travel with them.
--
-- 2. Categories. 877 of 2363 places arrived with no category, and most of them are
--    not places at all: bus stops, luggage lockers, public toilets, embassies,
--    hospitals, offices, bare street addresses, district names.

-- ── Photo provenance ────────────────────────────────────────────────────────

alter table public.places add column if not exists photo_source text;
alter table public.places add column if not exists photo_attribution text;
alter table public.places add column if not exists photo_checked_at timestamptz;
-- Keep the imported link even after a photo is replaced: re-running enrichment
-- should never be a one-way door.
alter table public.places add column if not exists photo_url_import text;

update public.places set photo_source = 'google'
where photo_url is not null and photo_source is null;

update public.places set photo_url_import = photo_url
where photo_url_import is null and photo_source = 'google';

create index if not exists places_photo_checked_idx on public.places (photo_checked_at nulls first);

-- The enrichment itself lives in the `enrich-photos` edge function. It runs in
-- 100-second slices, so pg_cron calls it until there is nothing left to check.
-- Stop it with: select cron.unschedule('enrich-photos');
create extension if not exists pg_net;
create extension if not exists pg_cron;

-- ── Categories and listing ──────────────────────────────────────────────────

alter table public.places add column if not exists is_listed boolean not null default true;

comment on column public.places.is_listed is
    'False for import noise (transport stops, services, bare addresses, districts). '
    'Hidden from the catalogue, search, map and route picker, but still readable by '
    'id so routes that already reference them keep working.';

-- The app has had an "Other" category since the beginning (PlaceCategory.other = 0);
-- the table never had the matching row.
insert into public.categories (id, name, icon, color)
values (0, 'Other', '📍', '#8E8E93')
on conflict (id) do nothing;

-- 1. Hide the obvious non-places, by the type Google gave them.
update public.places
set is_listed = false
where category_id is null
  and exists (
      select 1 from unnest(tags) t
      where t ~* '\mbus stop\M|\mtram stop\M|\mtransit\M|\msubway station\M|\mtrain station\M|\mbus station\M|\mbus depot\M|\mbus company\M|\mbus ticket\M|railway|\mtransport|\mparking\M|luggage|\mstorage\M|warehouse|bathroom|embassy|hospital|\mclinic\M|\mdoctor\M|dentist|pharmacy|\mmedical|salon|hairdress|massage|\mspa\M|beautician|\mnail\M|optician|barber|corporate office|business center|coworking|real estate|apartment|insurance|\mbank\M|\matm\M|gas station|car repair|law firm|\mlawyer\M|architect|civil engineer|\mschool\M|kindergarten|courier|post office|veterinar|filtration|food manufacturer|wholesaler|consultant|\mfoundation\M|association / organization|event management|event planner|\mbuilding\M|academic department|hospital department|city department'
  );

-- 2. Give the survivors a category, from the same Google types.
update public.places set category_id = case
    when exists (select 1 from unnest(tags) t where t ~* 'museum')                                                        then 6
    when exists (select 1 from unnest(tags) t where t ~* 'art gallery|art center|art centre|arts organization|art studio') then 8
    when exists (select 1 from unnest(tags) t where t ~* 'theat|opera|dance pavillion|cinema')                            then 9
    when exists (select 1 from unnest(tags) t where t ~* 'concert|stadium|arena|live music|\mevent venue\M')              then 14
    when exists (select 1 from unnest(tags) t where t ~* '\mpark\M|\mgarden\M|\mforest\M|\mlake\M|\mbeach\M|\mmarina\M|\mzoo\M|playground|water park') then 7
    when exists (select 1 from unnest(tags) t where t ~* 'vista point|observation|viewpoint|mountain peak')               then 12
    when exists (select 1 from unnest(tags) t where t ~* '\mmarket')                                                      then 13
    when exists (select 1 from unnest(tags) t where t ~* 'landmark|monument|church|cathedral|basilica|synagogue|mosque|castle|palace|cemetery|tourist attraction|religious destination|parish|\mbridge\M|memorial|library|universit|cultural center|community center') then 10
    when exists (select 1 from unnest(tags) t where t ~* '\mhotel\M|hostel|guest house')                                  then 16
    when exists (select 1 from unnest(tags) t where t ~* 'night club|nightclub|disco')                                    then 15
    when exists (select 1 from unnest(tags) t where t ~* '\mbar\M|\mpub\M|brewery|wine bar')                              then 4
    when exists (select 1 from unnest(tags) t where t ~* 'bakery|patisserie|\mcake\M')                                    then 5
    when exists (select 1 from unnest(tags) t where t ~* 'coffee')                                                        then 3
    when exists (select 1 from unnest(tags) t where t ~* '\mcafe\M|\mcafé\M|tea house|tea room')                           then 2
    when exists (select 1 from unnest(tags) t where t ~* 'restaurant|bistro|\mdiner\M|steak house')                       then 1
    when exists (select 1 from unnest(tags) t where t ~* '\mstore\M|\mshop\M|boutique|\mmall\M|bookstore')                then 11
    else category_id
end
where category_id is null and is_listed;

-- 3. What is left with no tags at all is geocoding debris: street names ("Hoża"),
--    plain addresses ("Mała 5") and district names ("Bemowo"). A real attraction
--    among them has either Google reviews or a route pointing at it — Krakowskie
--    Przedmieście and Rynek Starego Miasta survive on that second rule.
update public.places p
set is_listed = false
where p.category_id is null
  and coalesce(cardinality(p.tags), 0) = 0
  and coalesce(p.rating_reviews, 0) = 0
  and not exists (select 1 from public.route_stops s where s.place_id = p.id)
  and not exists (select 1 from public.tip_page_links l where l.place_id = p.id);

-- 4. Anything still uncategorised but visible is a real place of an odd type.
update public.places set category_id = 0 where category_id is null and is_listed;

-- The tiles on Explore promise "N places" behind a category. Hidden noise must not
-- be part of that count, or the tile opens onto fewer places than it advertised.
create or replace view public.place_category_counts
with (security_invoker = on) as
select category_id,
       count(*)::integer as place_count
from public.places
where category_id is not null
  and is_listed
group by category_id;
