-- Empty the "Other" bucket of everything that has an obvious home.
--
-- Google's tags describe what a business *is* ("Painting", "Plaza", "Notable
-- street"), not what a visitor comes for, so the import dropped murals, statues,
-- squares and named streets into category 0. That is exactly the material a
-- walking guide is made of, and sitting in "Other" it matched no category chip
-- and appeared in no Explore tile.

-- Murals, sculptures, monuments, squares, named streets and notable buildings.
update places set category_id = 10 where id in (
   40,  -- Al. Ujazdowskie
  240,  -- Byk
  259,  -- Capital Center for Cultural Education
  407,  -- DALeast Eagle & Snake Mural
  437,  -- Dionis Henkel Square
  464,  -- Szklany dom
  465,  -- Dom Romualda Traugutta
  768,  -- Institute of Archeology, University of Warsaw
  877,  -- Krakowskie Przedmieście
 1009,  -- Main Campus of the University of Warsaw
 1176,  -- Modernistyczny blok na Karowej
 1193,  -- Monument to the mass graves at the Jewish cemetery
 1223, 1224, 1226, 1231, 1232, 1236, 1238,   -- the seven murals
 1507,  -- plac Europejski
 1516,  -- plac Trzech Krzyży
 1521,  -- Plac Unii Lubelskiej
 1565,  -- Pomnik Praskiej Kapeli Podwórkowej
 1599,  -- Praskie aniołki
 1627,  -- Próżna
 1772,  -- Rynek Starego Miasta
 1798,  -- Sculpture "Giraffe"
 1868,  -- Soho Factory
 1950   -- Supreme Court of Poland
);

-- Green space.
update places set category_id = 7 where id in (
 1198,  -- Morysin
 1723   -- Rezerwat Przyrody Morysin
);

-- Galleries: one tagged "Photography studio", one tagged "Auction house".
update places set category_id = 8 where id in (602, 852);

-- Places you buy something in.
update places set category_id = 11 where id in (
 1006,  -- MADARE
 1575   -- Pracownia ceramiczna STRUM — sells its own work
);

-- A courtyard of bars off Nowy Świat, not an "Amusement center".
update places set category_id = 4 where id = 1426;

-- Sports facilities you book by the hour, and a bus station: same reasoning as
-- 20260821_hide_service_businesses.sql, they were just missing a blocklist tag.
update places set is_listed = false where id in (
   34,  -- Agrykola football pitch
   35,  -- Agrykola Warszawa (club)
   68,  -- Aqua Relaks (pool, sauna)
  870,  -- Korty Praga (tennis)
  921,  -- Kwadrat (fishing pond)
 1008   -- Main Bus Station
);

-- Deliberately left in "Other": Aura Kollektiv, Cud Malina, Moczydło Ice Rink,
-- Syreni Śpiew, Warsaw Tourist Information Center. The first four have no tags,
-- description or website to categorise them from, and the tourist office has no
-- category that fits. Guessing here would be worse than leaving them visible.

-- Applied 21 Aug 2026: "Other" 92 -> 5, Landmark 235 -> 264, listed 1575 -> 1569.
