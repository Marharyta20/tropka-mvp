-- Lets a tip be parked instead of deleted. "Packing Light" is generic travel
-- advice with nothing in the catalogue behind it, which makes no sense while the
-- app is Warsaw-only — but it will once there is more than one city.
alter table public.tips add column if not exists is_published boolean not null default true;

update public.tips set is_published = false where title = 'Packing Light';

-- A tip that is not about one city has no city.
update public.tips set city_id = null where title = 'Packing Light';
