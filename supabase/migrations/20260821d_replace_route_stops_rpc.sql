-- Replace a route's stops in one transaction.
--
-- The app used to issue a DELETE and then a separate INSERT. If the insert
-- failed — connection dropped between the two calls, session expired mid-save,
-- one stop violating a constraint — the route was left with no stops at all,
-- while stops_count had already been updated to the new number. The header then
-- claimed "7 stops" over an empty list, with no way for the author to recover.
--
-- SECURITY INVOKER (the default) on purpose: row level security still decides
-- whether this caller may touch this route's stops. The function only makes the
-- two writes atomic; it grants nobody anything.

create or replace function public.replace_route_stops(p_route_id uuid, p_stops jsonb)
returns void
language plpgsql
set search_path = ''
as $$
begin
  delete from public.route_stops where route_id = p_route_id;

  insert into public.route_stops (route_id, place_id, order_index, notes, photo_url, time_spent)
  select p_route_id,
         (s->>'place_id')::int,
         (s->>'order_index')::int,
         nullif(s->>'notes', ''),
         nullif(s->>'photo_url', ''),
         coalesce((s->>'time_spent')::int, 0)
  from jsonb_array_elements(coalesce(p_stops, '[]'::jsonb)) as s;
end;
$$;

grant execute on function public.replace_route_stops(uuid, jsonb) to authenticated;
