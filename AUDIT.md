# Audit — August 2026

A pass over every screen, service and model, plus the state of the data behind
them. Ordered by how much it costs to leave alone, not by how hard it is to fix.

Counts are live numbers from the database, last refreshed 21 Aug 2026.

---

## Done on 21 Aug

**Errors and empty states** — `ErrorBlock` / `ErrorBanner` added and wired into
the map, route detail, place detail, profile, Tips and the places feed. The rule
that came with it: if a `catch` assigns to a property, some view reads it.
`SavedRoutesStore` no longer treats a failed fetch as "nothing saved".
`ProfileViewModel.errorMessage` is cleared at the start of `fetchAll` so a stale
message cannot outlive the failure. Tips and the places feed no longer say
"nothing found" before the first request has started.

**Places feed pagination** — three defects: `loadMoreIfNeeded` now keys off
`visible` rather than `places`, a single network error no longer sets
`reachedEnd` for the session, and `reload()` carries a generation counter so a
page from the previous query is dropped instead of landing in a list that was
just cleared. `PlacesService.feed` sorts by `id` as a unique tiebreaker.

**Google ratings** — new `GoogleRating` component. The review count is gone; the
score, the star and an "on Google" label are one link to the place's Google
listing via `source_url`.

**Catalogue cleanup** — `20260821_hide_service_businesses.sql` hid 59 places a
visitor cannot walk into. `20260821b_recategorise_other_places.sql` emptied the
"Other" bucket from 92 to 5 — 29 murals, statues, squares, named streets and
notable buildings moved to Landmark.

**Delete Account now deletes the account** —
`20260821c_link_profiles_to_auth_users.sql` adds the missing
`public.users.id → auth.users.id` foreign key with `on delete cascade` (and
backfills six auth users that had no profile row), and the `delete-account` Edge
Function removes the auth user with the service role. The app calls the function
behind a confirmation dialog, and only reports success when the delete returned
one.

**Write paths no longer lie** — `SettingsViewModel.save()` returns whether the
write landed, so "Changes saved" and the profile header only update on success.
`RouteCardViewModel.toggle()` returns a `BookmarkOutcome` instead of a Bool, so a
failed save can no longer be reported as "Removed from your routes" and logged
to PostHog as `route_unsaved`.

**Data loss** — `replace_route_stops(uuid, jsonb)` replaces a route's stops in
one transaction instead of a DELETE followed by a separate INSERT. The route
editor copies the draft store instead of draining it, and clears it only after
the route exists, so backing out no longer discards everything collected on the
map. `drain()` is gone so the pattern cannot come back.

**Stops without coordinates** — `Stop.lat/lng` and `Stop.location` are optional,
matching the nullable columns. One bad row can no longer make the whole route's
stop list fail to decode; it simply is not drawn on the map.

**"I walked this route"** — new `route_completions` table with per-user RLS, a
`routes.completed_count` maintained by trigger, `RouteCompletionService`, a
toggle next to "Start walking", the count on the route's meta line, and the
review sheet opening right after someone marks a route walked. Reviewing is no
longer gated on the bookmark — anyone but the author can write one. A shared
`WalkedRoutesStore` puts a "Walked" badge on the Explore card and on every
profile row, and the profile has a fourth tab listing walked routes.

**Map** — the multi-page initial load can no longer start twice. The place card
opens at the same height every time.

---

## 0. The finding that is not a bug

The catalogue is wide and thin:

| | |
|---|---|
| Listed places | 1569 |
| …with a Google rating | 1548 |
| …with opening hours | 951 |
| …with a short description | 644 |
| **…with a live photo** | **189** |
| **…with a `tropka_notes` line** | **2** |
| Public routes | 5 |
| Published tips | 3 |

Two numbers carry the whole story.

**1380 of 1569 places still point at a dead `lh3.googleusercontent` URL**, so
almost nine places in ten render the category placeholder. The app looks empty
because it is. Known, costed and deliberately deferred — see `PRE-RELEASE.md` —
but it is the first thing anyone will notice.

**`tropka_notes` is filled in for two places.** It is the only field in the
schema that carries an opinion rather than an import. Everything else on a place
card is a Google export, so on 99.9% of places the app is a worse Google Maps.
The routes are the product; there are five of them.

Nothing below matters as much as these two lines.

---

## 1. Still open

### 1.1 Explore only ever searches 50 routes
`Services/SupabaseService.swift:25` has `.limit(50)`; `ExploreView.swift:35`
filters that array in memory. Route 51 and beyond cannot be found by search, and
the tag chips and "Route of the day" are drawn from the same truncated set.
Invisible at 5 routes, silently wrong the moment there are 51.

### 1.2 Location permission is requested on a text screen
`Views/TourDetailsView.swift:86` — tapping any Explore card raises the iOS
location dialog immediately, before a map is visible, with the reason "to show
where you are on the map". Ask when the map opens instead; the accept rate on a
prompt that makes sense is much higher.

### 1.3 Place detail lists other people's private routes
`Services/PlacesService.swift:162` has no status filter, and RLS does not add
one — `20260817_enable_rls.sql` allows `select … using (true)` on routes. Any
signed-in user can see and open someone's unpublished draft from a place page.
Currently harmless (all 5 routes are public) and a data leak the moment someone
saves a draft.

### 1.4 Sign-up breaks if email confirmation is ever enabled
`Services/AuthService.swift:40` upserts the profile row straight after `signUp`.
With confirmation on there is no session yet, RLS (`to authenticated`) rejects
the write, and the user sees a raw row-level-security error. The retry then
fails with "User already registered". Note that `handle_new_auth_user` already
creates the profile row, so this write may not be needed at all.

### 1.5 Stale search results overwrite fresh ones
`Views/RouteEditor/PlacePickerView.swift:75` cancels the previous task, but
nothing checks `Task.isCancelled` after the network `await`, so a slow earlier
request can overwrite a newer one. `PlaceSearchView.swift:168` does it correctly.

---

## 2. Code that ships and does nothing

- `Views/PlaceSearchView.swift` — a complete 215-line search screen with debounce,
  retry and empty states. No screen presents it; the only reference is its own
  `#Preview`.
- `Views/RoutesListView.swift` — commented out of `MainTabView.swift:28`,
  unreachable, still compiled in along with its view model and a Sign Out button.
- `Views/Map/MapScreenView.swift` — the +/− zoom stack, labelled
  development-only in its own comment.

---

## 3. Worth building, in order

1. **`tropka_notes` on the places that matter.** Not all 1569 — the ~100 a
   visitor actually reaches. This is the difference between a guide and a dump.
   Needs an editor in the app, or a spreadsheet round trip, plus someone writing
   the lines.
2. **Photos.** 1380 dead links. Costed and deferred in `PRE-RELEASE.md`, but it
   is what makes the app look unfinished.
3. **Offline for a saved route.** A tourist walking Warsaw with roaming off
   currently gets nothing. Caching stops and coordinates for saved routes is a
   small change with a large payoff in the exact situation the app is for.
4. **Share a route.** No way to send one to anyone. The cheapest growth
   mechanism there is, and it needs a universal link, which needs planning
   before release rather than after.
5. **More routes.** Five is not a catalogue. Every other item on this list is
   improving the frame around five routes.
