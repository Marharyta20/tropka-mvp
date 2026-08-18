-- Tips used to be a dead end: a page named a cafe the catalogue already knows
-- and gave the reader no way to open it. This links a tip page to the places
-- (or routes) it talks about.

create table if not exists public.tip_page_links (
    id          uuid primary key default gen_random_uuid(),
    tip_page_id uuid not null references public.tip_pages(id) on delete cascade,
    place_id    integer references public.places(id) on delete cascade,
    route_id    uuid references public.routes(id) on delete cascade,
    position    integer not null default 0,
    -- A link points at exactly one thing.
    constraint tip_page_links_single_target check (num_nonnulls(place_id, route_id) = 1)
);

create index if not exists tip_page_links_page_idx
    on public.tip_page_links (tip_page_id, position);
create unique index if not exists tip_page_links_page_place_key
    on public.tip_page_links (tip_page_id, place_id) where place_id is not null;
create unique index if not exists tip_page_links_page_route_key
    on public.tip_page_links (tip_page_id, route_id) where route_id is not null;

alter table public.tip_page_links enable row level security;

-- Same rule as the tips themselves: readable by any signed-in user, written
-- only through the dashboard.
create policy "tip_page_links readable" on public.tip_page_links
    for select to authenticated using (true);

-- Links for the tips that exist today. Matched by name so the file stays
-- readable; places absent from the catalogue are simply skipped.
with page as (
    select p.id, t.title as tip, p.order_index
    from public.tip_pages p
    join public.tips t on t.id = p.tip_id
),
link (tip, idx, place_name, pos) as (values
    ('Coffee Culture in Warsaw', 1::int, 'cor. specialty coffee', 0),
    ('Coffee Culture in Warsaw', 1, 'Tekla - kawa i winyle', 1),
    ('Coffee Culture in Warsaw', 2, 'Cornerstone Specialty Coffee', 0),
    ('Coffee Culture in Warsaw', 2, 'Ave Coffee Speciality', 1),
    ('Hidden Praga', 1, 'Koneser Grill', 0),
    ('Hidden Praga', 1, 'W Oparach Absurdu.', 1),
    ('Hidden Praga', 2, 'Mural You Will Never Be Younger Than Now', 0),
    ('Hidden Praga', 2, 'mural "Ania"', 1),
    ('Hidden Praga', 2, 'Mural "Torba Praska"', 2),
    ('Hidden Praga', 3, 'TABLES | modern bistro', 0),
    ('Hidden Praga', 3, 'Praska Gazela', 1),
    ('Hidden Praga', 3, 'ARTBISTRO STALOWA 52', 2),
    ('Warsaw on a Budget', 1, 'POLIN Museum of the History of Polish Jews', 0),
    ('Warsaw on a Budget', 1, 'Muzeum Narodowe w Warszawie', 1),
    ('Warsaw on a Budget', 1, 'Warsaw Uprising Museum', 2),
    ('Warsaw on a Budget', 2, 'Prasowy', 0),
    ('Warsaw on a Budget', 2, 'Bar Bambino', 1),
    ('Warsaw on a Budget', 4, 'Vistula Boulevards', 0),
    ('Warsaw on a Budget', 4, 'Bulwar Jana Karskiego', 1)
)
insert into public.tip_page_links (tip_page_id, place_id, position)
select page.id, pl.id, link.pos
from link
join page on page.tip = link.tip and page.order_index = link.idx
join public.places pl on pl.name = link.place_name
on conflict do nothing;

-- Two of the restaurants this page recommended are not in the catalogue at all,
-- so the text now names ones the reader can actually open.
update public.tip_pages
set body = 'Skip the tourist menus. TABLES on Ząbkowska, Praska Gazela a few doors down and ARTBISTRO on Stalowa are where Warsaw food lovers actually go.'
where id = (
    select p.id from public.tip_pages p
    join public.tips t on t.id = p.tip_id
    where t.title = 'Hidden Praga' and p.order_index = 3
);

-- The @handles in the footers looked like sources but belonged to no one.
update public.tip_pages set footer = '— Tropka team' where footer like '%@%';
