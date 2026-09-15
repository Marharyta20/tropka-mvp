-- Two problems with the first Wikipedia pass, both visible on one card.
--
-- 1. The text came back in Polish. The app is in English, and a Polish paragraph
--    under an English heading is not a summary, it is noise for most readers.
--
-- 2. The name test was too loose. "Kamienica" (a tenement house on Wąski Dunaj)
--    matched the article for "Kamienica Pod Okrętem" — a different building, on
--    a different street, 300 metres away but well inside the radius. The card
--    then stated the wrong address in its own description. Same failure put the
--    article about the Wilanów Palace on its guardhouse, and the article about
--    the Marymont district on a church that merely has "Marymont" in its name.
--
-- The rule was `shared / min(words)`, which reaches 1.0 whenever the shorter of
-- the two names is fully contained in the longer one — so any place whose name
-- happens to contain a district, street or building-type word matched that
-- district's article. The replacement requires both names to be mostly covered
-- by what they share, ignoring purely geographic filler ("w Warszawie", "aleja").
--
-- Everything written by the first pass is discarded rather than patched: it is
-- 30-odd rows, and a description that confidently names the wrong street is
-- worse than an empty field.

alter table public.places
  add column if not exists summary_url text;

comment on column public.places.summary_url is
  'Link to the source article. CC BY-SA requires the source to be reachable, not just named.';

update public.places
   set summary = null,
       summary_source = null,
       summary_attribution = null,
       summary_url = null
 where summary_source = 'wikipedia';

-- Let the second pass reconsider everything: the matching rule changed, and so
-- did the language requirement.
update public.places
   set summary_checked_at = null
 where summary_checked_at is not null;
