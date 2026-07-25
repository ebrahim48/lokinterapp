# Lokinter Mobile — API Findings for Backend

Tested on **2026-07-15** against `https://api.ssh.bd/api/v1` with the shared test
account (`sushil500530@gmail.com`, user id 1). Every endpoint the mobile app uses
was called directly *and* driven through the app on an **iPhone 16e** simulator
(automated walk: 22/22 screens loaded real data — login, home, search, post
details, deals, chat inbox, profile, my-posts, reviews, wallet, notifications,
basic-info). Items are ordered by how hard they block the app.

> **§0 — one thing to fix first (breaks images app-wide):** the API returns media
> URLs on `https://dev-dashboard.lokinter.com/...` which **404**, while the exact
> same media id serves **200** on `https://api.ssh.bd/...`. This affects banners,
> post attachments, and avatars. The app currently rewrites the host as a
> workaround, but please set `APP_URL` / the media base to `api.ssh.bd` so URLs
> are correct at the source.
> ```
> 404  https://dev-dashboard.lokinter.com/api/v1/media/6fd14e4a-.../stream
> 200  https://api.ssh.bd/api/v1/media/6fd14e4a-.../stream
> ```

---

## 1. Blockers

### 1.1 No cities seeded — local posts are impossible
`GET /countries/getCitiesByCountryIso/{iso}` returns `data: []` for every
country tried (US, FR, TN, BD). At the same time, creating a LOCAL post
validates:

```
422 — The from city field is required when post location is LOCAL.
      The to city field is required when post location is LOCAL.
```

So **no user can create a local trip or local delivery request**: the city
dropdowns in the app have nothing to show, and the API rejects the post without
cities. → Please seed the cities table (or expose whatever source the web app
uses).

### 1.2 "My requests & trips" rows are stripped down
`GET /deals/getAllDeals?status=TRIP|DELIVER` returns the user's own posts as:

```json
{"id": 3, "location": "INTERNATIONAL", "from": "France", "to": "United States",
 "beforeDate": "08/20/2026 06:00 AM", "status": "TRIP", "flag": "POST"}
```

No `type`, `title`, `weight`, `wantTo`, `categoryTitle`, `user`, or
`attachUrl` — unlike the full shape from `getPosts`. The app renders these
cards with weight 0 and no title/image. → Return the same post resource that
`getPosts` uses (or add a dedicated `GET /posts/myPosts`).

---

## 2. Fields the app collects/displays but the API doesn't support

| Field | Where in the app | What the API does today |
|---|---|---|
| `description` (item description) | Post-a-request form + request cards | Sent by the app, **not stored, not returned** |
| `profit` + `currency` (traveler reward) | Post-a-request form + shown on request cards ("PROFIT") | Not accepted, not returned |
| `remainingWeight` | Trip cards show "X kg space left" | Only total `weight` exists, so the app can't show remaining capacity |
| Transporter role + business info (legal name, address, operating countries, license + legal docs) | Register screen (client requirement) | Register only accepts firstName/lastName/country/phone/email/password; no transporter concept on users (`type` is `null`) |
| Notification settings toggles (push / trip / request / marketing) | Notification settings sheet | No endpoints (already listed as "proposed" in the API guide) — app stores them locally meanwhile |

---

## 3. Documentation vs. actual behavior

These work, but differently from the API guide — worth fixing the docs or the
validation:

1. **`POST /posts/addNewPost` requires more fields than documented.**
   `pickupLocation` and `dropoffLocation` are **required** for both TRIP and
   DELIVER; `rejectedCategoriesIds` is **required** for TRIP (an empty `[]`
   passes). The guide shows them as optional/extra. The mobile forms now
   include pickup/dropoff fields because of this.
2. **`POST /auth/refreshToken` contract.** Docs imply the refresh token goes in
   the header; the endpoint actually validates a JSON body:
   `{"accessToken": "...", "refreshToken": "..."}` (422 otherwise).
3. **`GET /auth/user` rotates the token pair on every call** and embeds
   `token.accessToken/refreshToken` in the response. The app now adopts the new
   pair, but please confirm this is intended — it silently invalidates nothing
   but creates a new token row per call.
4. **Numeric fields returned as strings.** `weight` comes back as `"5"`
   (string). Harmless now that the app parses defensively, but inconsistent
   with the docs' numbers.
5. **Empty relations returned as `[]`.** `fromCity`/`toCity` are `[]` when
   unset (instead of `null`), which reads as "empty list" not "no city".
6. **`POST /deals/addNewDeal` requires `receiverName` and `receiverPhone`.**
   Both are listed as optional in the guide, but omitting them 422s. The
   agreement sheet now marks them required. Confirm whether they should stay
   mandatory for a TRIP-side agreement, where the sender may not know the
   receiver yet.
7. **`GET /deals/getById/{id}` has no "who proposed this deal" field.** The
   party who confirmed the agreement must not be offered "Accept deal" on their
   own proposal. With no `createdBy`/`proposedBy` in the payload the app infers
   it from the post type (sender proposes on a TRIP, traveler on a DELIVER),
   which holds only because the app is the sole creator of deals. Please add an
   explicit creator id so this doesn't have to be derived.
8. **`itemEstimatedCost` and `sdRequired` are accepted but not persisted.**
   `GET /deals/getById/{id}` returns `itemEstimatedCost: null` on a deal that
   was created with a value. The escrow breakdown depends on it, so it needs
   to be stored.

---

## 4. Bugs

1. **`GET /chats/getChatDetails/{receiver_id}` with a nonexistent user returns
   an HTTP 500 HTML error page** (SQL FK violation:
   `chats_receiver_id_foreign`). Should be a clean 404 JSON envelope.
2. `GET /rates/getUserInfo` puts verification flags under `data.user`
   (`emailVerified`, `phoneVerified`, `documentVerified`) while other endpoints
   use `identityVerified` at top level — pick one name/location.

---

## 5. Seeding requests for the dev environment

Testing beyond this point needs data that one account can't create:

1. **A second test user** (with known credentials) so chat and the whole deal
   lifecycle can be exercised: `addNewDeal`, accept/decline (`changeStatus`),
   `markAsCompleted`, `addRate`, disputes.
2. **Real categories** — only "Bundle Fuse" and "Demo Categ" exist.
3. A few trips/requests from that second user so Home's "recommended
   travelers" and search results show somebody other than the tester.

---

## 6. What was verified working ✅

- `POST /auth/login`, `GET /auth/user`, `POST /auth/updateProfile` (JSON body
  works, country/phone persisted)
- `GET /home/mobile` (banners with mobile image URLs, recommendedTravelers,
  latestDeals — new trips show up immediately)
- `GET /posts/getPosts` (searchAs TRIP/DELIVER, pagination envelope),
  `GET /posts/getById/{id}`
- `POST /posts/addNewPost` for INTERNATIONAL TRIP and DELIVER (with the extra
  required fields from §3.1), `DELETE /posts/deletePost/{id}` (exercised via
  the app's My-posts delete)
- `GET /lookups/getAllCategories`, `GET /lookups/getHomeBanners`,
  `GET /countries/getAllCountries` (250 countries with id/name/iso2)
- `GET /rates/getUserInfo`, `GET /rates/getUserRates`
- `GET /wallet/`, `GET /wallet/payout-methods` (incl. Stripe-eligibility
  messaging)
- `GET /notifications/getNotifications`, `POST /notifications/markAllAsRead`
- `GET /chats/getAllChats`
- `GET /deals/getAllDeals` (status filters respond; no deals exist yet to test
  the lifecycle)

## 7. Not tested (needs §5 seeding or a real device)

- Deal lifecycle end-to-end (create/accept/decline/cancel/complete/rate) — one
  account can't be both sender and traveler
- Chat send/receive between two users
- `POST /auth/register` OTP flow (would need a fresh inbox), forgot/reset
  password emails
- File uploads (chat attachments, post images) — app UI for picking files is
  still a placeholder
- KYC, WhatsApp phone OTP, disputes, QR codes, payout request execution
  (no balance), pickup/delivery videos
