-- Tell an author that somebody reviewed their route.
--
-- The one notification the app has earned: it is about something a specific
-- person made, it happens rarely, and the author cannot find out any other way
-- without opening the route and counting.
--
-- Fire and forget. `net.http_post` returns a request id immediately and the
-- reply is collected later, so a slow or misconfigured APNs cannot delay — or
-- fail — the insert of the review itself. Until the APNs secrets are set the
-- send-push function answers 500 and nothing else happens, which is the intended
-- behaviour rather than an error to chase.
--
-- NOTE: the Authorization header carries the project's anon key, inline. That is
-- the same key that ships inside the app binary and in SupabaseClient.swift, so
-- it is public by design and grants nothing on its own; the function authorises
-- itself with the service role internally. It is written out rather than read
-- from a setting so that this file reproduces exactly what is deployed.

create or replace function public.notify_route_author_of_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  author uuid;
  route_title text;
  reviewer_name text;
begin
  select r.author_uid, r.title into author, route_title
    from public.routes r where r.id = new.route_id;

  -- Nobody needs telling about their own review.
  if author is null or author = new.user_id then
    return new;
  end if;

  select coalesce(u.full_name, u.username, 'Someone') into reviewer_name
    from public.users u where u.id = new.user_id;

  perform net.http_post(
    url := 'https://zhoaeejqsczwcldbonwj.supabase.co/functions/v1/send-push',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpob2FlZWpxc2N6d2NsZGJvbndqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyODc0MzYsImV4cCI6MjA5NTg2MzQzNn0.uRrajc4dlLGGLyMFuImBvzS0kBUuDRWd1Bpran1xWe4"}'::jsonb,
    body := jsonb_build_object(
      'user_id',  author,
      'title',    reviewer_name || ' reviewed your route',
      'body',     route_title,
      'type',     'review',
      'route_id', new.route_id
    )
  );

  return new;
end;
$$;

drop trigger if exists reviews_notify_author on public.reviews;
create trigger reviews_notify_author
after insert on public.reviews
for each row execute function public.notify_route_author_of_review();
