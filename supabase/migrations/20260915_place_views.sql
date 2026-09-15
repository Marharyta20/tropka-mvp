-- How often each place is opened.
--
-- "Place of the day" is meant to weigh popularity as well as distance, and
-- nothing in the database knew how often anything was opened: the events went
-- to PostHog, which the app cannot read back. This starts the count now so the
-- number is worth something by the time it is used.
--
-- A running total rather than one row per view: the app only ever needs the
-- ranking, and a per-view log of a few thousand places would grow without
-- limit for a figure nobody reads at that resolution.
create table if not exists public.place_views (
    place_id   bigint primary key references public.places(id) on delete cascade,
    views      bigint not null default 0,
    updated_at timestamptz not null default now()
);

alter table public.place_views enable row level security;

-- Readable by anyone signed in: the ranking is not private, and the home screen
-- needs it. Writes go only through the function below, so no client can set an
-- arbitrary count.
drop policy if exists "place_views readable" on public.place_views;
create policy "place_views readable"
    on public.place_views for select
    to authenticated
    using (true);

-- `security definer` so the caller needs no write access of its own, and an
-- empty search_path so the body cannot be pointed at another schema's `places`.
create or replace function public.record_place_view(p_place_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Ignores ids that are not real places: the foreign key would otherwise turn
    -- a stale link in the app into a visible error for something the user never
    -- asked to happen.
    if not exists (select 1 from public.places where id = p_place_id) then
        return;
    end if;

    insert into public.place_views (place_id, views, updated_at)
    values (p_place_id, 1, now())
    on conflict (place_id) do update
        set views = public.place_views.views + 1,
            updated_at = now();
end;
$$;

revoke all on function public.record_place_view(bigint) from public;
grant execute on function public.record_place_view(bigint) to authenticated;

-- The only query that will ever run against this table.
create index if not exists place_views_views_idx
    on public.place_views (views desc);
