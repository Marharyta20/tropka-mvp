# Push notifications — what is done and what is left

The client, the schema and the sender are written. Three steps remain, and all
three need an Apple Developer account, so none of them can be done from here.

## What already works

- `PushService` asks for permission, receives the APNs device token and stores it.
- `device_tokens` holds one row per device, with the environment it was issued in.
- `users.notifications_enabled` is the in-app switch, separate from the OS permission.
- Settings has a Notifications section that copes with all three OS states.
- The `send-push` Edge Function signs an APNs token and sends to the right host.
- A trigger on `reviews` calls it when somebody reviews a route you published.

## Step 1 — Xcode capability

Xcode → target Tropka → **Signing & Capabilities** → **+ Capability** →
**Push Notifications**.

This adds the `aps-environment` entitlement. Xcode also enables the push service
on the App ID in your developer account, which is why it cannot be done by
editing files.

## Step 2 — the APNs key

developer.apple.com → Certificates, Identifiers & Profiles → **Keys** → **+** →
tick **Apple Push Notifications service (APNs)** → Continue → Register →
**Download**. The `.p8` downloads once and only once.

Note three things from that page: the **Key ID** (10 characters), your **Team ID**
(top right of the developer portal), and the **bundle identifier** of the app.

## Step 3 — the four secrets

Supabase Dashboard → Project Settings → **Edge Functions** → **Secrets**:

| name | value |
|---|---|
| `APNS_KEY_ID` | the 10-character Key ID |
| `APNS_TEAM_ID` | the 10-character Team ID |
| `APNS_PRIVATE_KEY` | the whole contents of the `.p8`, including the BEGIN/END lines |
| `APNS_TOPIC` | the bundle identifier |

Until these exist, `send-push` answers 500 with a message saying so. Nothing
else breaks: the trigger is fire-and-forget, so a review still saves.

## Testing before any of that

The simulator can display a notification without APNs, an account or a key. It
proves the payload, the banner and the tap handling — not the delivery.

```bash
cat > /tmp/review.apns <<'JSON'
{
  "Simulator Target Bundle": "com.yourcompany.Tropka",
  "aps": { "alert": { "title": "Anna K reviewed your route", "body": "Classic Warsaw: A Full Day" }, "sound": "default" },
  "type": "review",
  "route_id": "00000000-0000-0000-0000-000000000000"
}
JSON

xcrun simctl push booted com.yourcompany.Tropka /tmp/review.apns
```

Replace the bundle identifier with the real one in both places.

## One caveat worth knowing

A debug build registers with the APNs **sandbox**, a release build with
**production**. They are separate services with separate tokens, and sending a
sandbox token to the production host returns `BadDeviceToken` — an error that
says nothing about what is actually wrong. Each token row records which
environment it came from and `send-push` picks the host from it, so this should
never bite. If it ever does, that is the first thing to check.
