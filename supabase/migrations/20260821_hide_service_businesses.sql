-- Hide places a visitor cannot walk into off the street.
--
-- The catalogue was imported from Google, which does not distinguish "a place to
-- go and see" from "a business with an address". That left private practices,
-- company offices, appointment-only studios, luggage lockers and tour operators
-- sitting in a walking guide next to museums and cafes: a clinical dietitian's
-- practice was showing up as a place to visit.
--
-- Hidden with is_listed, not deleted: routes may reference a row, and a wrong
-- call here should be reversible with one UPDATE.
--
-- The rule: a place is hidden when it carries a tag from the blocklist below AND
-- carries no tag that would justify a visit. That second half is what keeps a
-- hotel with a gym, or a restaurant that also caters, in the catalogue.

with junk(tag) as (values
  -- Services you book, not places you walk into
  ('Nutritionist'),('Translation service'),('Personal trainer'),('Interior designer'),
  ('Party planner'),('Event planner'),('Meeting planning service'),('Delivery service'),
  ('Flower delivery'),('Air conditioning system supplier'),('Chauffeur service'),
  ('Car rental agency'),('Photo booth'),('Photographer'),('Boat rental service'),
  -- Companies and institutions, i.e. somebody's office
  ('Holding company'),('Company'),('Aerospace company'),('Electric utility company'),
  ('Book publisher'),('Newspaper publisher'),('Research institute'),
  ('Non-governmental organization'),('Foreign consulate'),('Supreme court'),
  ('Educational institution'),('Student housing center'),('Business center'),
  ('Musical instrument manufacturer'),
  -- Somewhere people live
  ('Housing development'),('Condominium complex'),('Gated community'),
  -- Transport plumbing rather than destinations
  ('Light rail station'),('Railroad company'),('Train ticket office'),
  ('Train ticket agency'),('Airport'),('Bike sharing station'),
  ('Luggage storage facility'),('Public bath'),
  -- Rooms and studios hired by the hour
  ('Recording studio'),('Photography studio'),('Pilates studio'),('Yoga studio'),
  ('Gym'),('Fitness center'),('Squash court'),('Table tennis facility'),
  ('Painting lessons'),('Pottery classes'),('Conference center'),
  ('Function room facility'),('Wedding venue'),('Wedding buffet'),('Wedding bakery'),
  -- Competitors, not places
  ('Tour agency'),('Hiking guide'),('Tour operator')
),
good(tag) as (values
  ('Restaurant'),('Cafe'),('Coffee shop'),('Bar'),('Bakery'),('Museum'),('Park'),
  ('Tourist attraction'),('Historical landmark'),('Art gallery'),('Hotel'),('Monument'),
  ('Sculpture'),('Painting'),('Memorial'),('War memorial'),('Church'),('Catholic church'),
  ('Cultural landmark'),('Historical place'),('Observation deck'),('Scenic spot'),
  ('Garden'),('City park'),('Castle'),('Night club'),('Pastry shop'),('Ice cream shop'),
  ('Book store'),('Performing arts theater'),('Movie theater'),('Concert hall'),
  ('Live music venue'),('Shopping mall'),('Cemetery'),('Library')
),
-- Landmarks the blocklist would otherwise catch by their Google tag. The Jewish
-- Historical Institute is tagged "Research institute"; the Szklany Dom, one of
-- the city's best-known modernist buildings, is tagged "Company". These stay,
-- and are worth re-categorising by hand later.
keep(id) as (values
  (259),   -- Capital Center for Cultural Education
  (464),   -- Szklany dom
  (602),   -- Galeria Asymetria
  (768),   -- Institute of Archeology, University of Warsaw
  (790),   -- Jewish Historical Institute
  (1009),  -- Main Campus of the University of Warsaw
  (1176),  -- Modernistyczny blok na Karowej
  (1575),  -- Pracownia ceramiczna STRUM
  (1868),  -- Soho Factory
  (1950)   -- Supreme Court of Poland
),
-- Caught by name rather than tag: a vet clinic, a limited company with no tags
-- at all, and bare residential addresses left over from geocoding.
extra(id) as (values (1), (27), (396), (1622), (2216), (2274), (2337))

update places p
set is_listed = false
where p.is_listed
  and (
        p.id in (select id from extra)
     or (exists (select 1 from junk j where j.tag = any(p.tags))
         and not exists (select 1 from good g where g.tag = any(p.tags)))
      )
  and p.id not in (select id from keep);

-- Applied 21 Aug 2026: 1634 listed places -> 1575.
