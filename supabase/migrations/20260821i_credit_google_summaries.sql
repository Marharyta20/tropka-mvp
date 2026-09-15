-- Every description says where it came from, or none of them should.
--
-- Wikipedia summaries carry an article name and a link, because CC BY-SA
-- requires it. The 219 summaries that came from the Google import carried
-- nothing, so two visually identical blocks sat on two cards and only one was
-- credited — which reads as a bug even before you ask whose text it is.
--
-- It is Google's editorial copy, and it is being stored well past what their
-- terms allow, unattributed. Crediting it does not fix the storage question,
-- but it does stop the app presenting someone else's writing as its own, and it
-- points at the listing the text describes. `source_url` already holds a working
-- Google Maps deep link for effectively the whole catalogue — the same link the
-- rating uses.
--
-- These rows are temporary in any case: the Wikipedia pass replaces them as it
-- finds proper articles.

update public.places
   set summary_attribution = 'Google',
       summary_url = source_url
 where summary_source = 'google'
   and summary_attribution is null
   and source_url is not null;

-- A handful have no source_url at all. Name the source anyway; a credit without
-- a link is still a credit, and the view falls back to plain text.
update public.places
   set summary_attribution = 'Google'
 where summary_source = 'google'
   and summary_attribution is null;
