-- A real one-line description of a place, kept apart from the review quote.
--
-- `short_description` came out of the import holding two different things: an
-- actual quote from somebody's review ("Very tasty and great service") and
-- Google's own editorial copy ("Small botanic garden with greenhouses, an
-- orangery, a herbarium and regular festivals & events"). The app showed both in
-- italics under "What people say", so on 235 places a description was presented
-- as something a visitor said.
--
-- The quote stays where it is. This column is for the description, and it can be
-- filled from a source that is free, does not expire and may be redistributed:
-- Wikipedia, under CC BY-SA, which is why the attribution column is not optional
-- in practice.

alter table public.places
  add column if not exists summary             text,
  add column if not exists summary_source      text,
  add column if not exists summary_attribution text,
  -- Set whether or not an article was found, so a second pass does not re-ask
  -- Wikipedia about the 1300 cafes it will never have heard of.
  add column if not exists summary_checked_at  timestamptz;

comment on column public.places.summary is
  'One-line description of the place. Source named in summary_source.';
comment on column public.places.summary_source is
  'wikipedia | google — where the text came from, so it can be attributed and replaced.';

-- Google's editorial summaries are already the right kind of text, so move them
-- across and leave only genuine quotes behind in short_description.
update public.places
   set summary = trim(short_description),
       summary_source = 'google'
 where summary is null
   and short_description is not null
   and trim(short_description) <> ''
   and left(trim(short_description), 1) not in ('"', '“', '«');

update public.places
   set short_description = null
 where summary_source = 'google';
