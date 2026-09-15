-- Keep the source text, in the language it was written in.
--
-- Dropping a Polish article because it has no English counterpart threw away the
-- only description that will ever exist for a lot of Warsaw: the Polish
-- Wikipedia covers this city far better than the English one, and a monument
-- with no en article is not going to grow one.
--
-- So the match is kept whatever language it is in. `summary_original` holds the
-- text as written, `summary_lang` says which language that is, and `summary`
-- holds what the app actually shows — the English article's own text where one
-- exists, a translation of the original where it does not.
--
-- This is also the shape a second language needs later. Translating from the
-- original is right; translating a translation is not, and once the original is
-- discarded that choice is gone.

alter table public.places
  add column if not exists summary_original text,
  add column if not exists summary_lang     text;

comment on column public.places.summary_original is
  'The source text as written, in summary_lang. Never overwritten by a translation.';
comment on column public.places.summary_lang is
  'Language of summary_original (ISO 639-1). The language of `summary` is always en for now.';
comment on column public.places.summary_source is
  'wikipedia | wikipedia-translated | wikipedia-pending | google';

-- Redo the lot: the previous passes stored no original, and the ones before that
-- were matched by a rule that has since been replaced.
update public.places
   set summary = null,
       summary_source = null,
       summary_attribution = null,
       summary_url = null,
       summary_original = null,
       summary_lang = null,
       summary_checked_at = null
 where summary_source is distinct from 'google';
