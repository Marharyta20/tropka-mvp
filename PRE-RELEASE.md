# Pre-release checklist

Things deliberately postponed while the app is in active development. Each entry
says what is blocked, why it was left for later, and what to do about it.

## Auth

### Leaked password protection — needs Pro
- **Status:** off. The dashboard toggle exists on the Free plan but saving fails:
  *"Configuring leaked password protection via HaveIBeenPwned.org is available on
  Pro Plans and up."*
- **Where:** Authentication → Sign In / Providers → Email.
- **Why it matters:** rejects passwords that already appear in public breach
  dumps. Supabase's Security Advisor flags its absence on every plan, so the
  warning will keep showing until this is switched on.
- **Do when:** the project moves to Pro (same moment as custom SMTP below).

### Password rules — left at six characters for now
- Minimum length stays 6, the Supabase default. Raising it to 8 and requiring
  letters plus digits is available on the Free plan (Authentication → Sign In /
  Providers → Email) and costs nothing but a decision — postponed on purpose so
  testing accounts stay easy to type.
- The app mirrors whatever the server enforces (`AuthViewModel.register`,
  `ForgotPasswordView`); if the dashboard value changes, change these two too or
  the user will be rejected after the round trip instead of before it.
- Existing passwords are unaffected by a rule change; it applies on sign-up and
  password change only.
- **Do when:** opening up to real users — tighten together with leaked password
  protection.

### Email delivery — built-in SMTP is a development-only crutch
- **Status:** using Supabase's built-in SMTP.
- **Limits:** a handful of emails per hour, and messages land in spam often
  enough that a real user would never find their recovery code.
- **Do when:** before any real users. Set up a custom SMTP provider (Resend,
  Postmark, SES) under Authentication → Emails → SMTP Settings.

### Recovery email template
- The **Reset password** template must contain `{{ .Token }}` — the app's
  recovery flow asks for the six-digit code, not the link. If someone restores
  the default template, recovery silently breaks: the email arrives, the code
  does not.

## Photos

### Google Places photos — deliberately deferred, costs money
- **Status:** 1423 of 1634 listed places still carry dead `lh3.googleusercontent`
  links (Google's photo URLs expire after a few weeks). 244 places have live
  Wikimedia photos; everything else falls back to the category placeholder.
- **What makes it fixable:** `places.source_url` holds the Google `place_id` for
  2361 of 2363 rows, so photo references can be re-fetched at any time.
- **Cost:** Place Details Essentials is free up to 10k calls/month; Place Photos
  gives 1000 free per month, then about $7 per 1000 — roughly $8 one-off for the
  whole catalogue, or nothing if spread across two months.
- **Catch:** Google's terms do not allow storing their photos long-term (place_id
  may be kept indefinitely, other content max 30 days). So this is a monthly
  refresh job, not a one-time import — that is exactly why the original links
  died.
- **Do when:** close to App Store release, together with the Pro upgrade.

## Interface

### Zoom buttons on the map — development crutch
- `MapScreenView.mapControls` draws +/- buttons above the locate button, driven by
  `zoomInTrigger` / `zoomOutTrigger` on `MapboxMapView`.
- They exist because pinch-zooming in the Simulator is awkward. Phones have
  fingers; every mainstream map app dropped these years ago.
- **Do when:** before the App Store build — delete the `zoomButton` helper, the two
  triggers, and `zoomIfNeeded` in the coordinator. `locateButton` stays.

## Ideas parked

- Isochrones on the map ("what is within a 15-minute walk"), free with the
  existing Mapbox token.
- Interactive basemap POIs (Maps SDK v11 featuresets) — tapping a restaurant
  Mapbox drew rather than one of ours.
- `tropka_notes` editor in the app for editors (needs an `is_editor` flag and an
  RLS policy).
- "Packing Light" tip is unpublished (`tips.is_published = false`) — generic
  travel advice with nothing in the catalogue behind it. Bring it back when the
  app covers more than one city.
