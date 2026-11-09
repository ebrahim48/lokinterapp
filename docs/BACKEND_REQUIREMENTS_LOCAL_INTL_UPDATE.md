# Lokinter Backend — API Contract for the Local & International Update

> **Written:** 09 Nov 2026
> **Audience:** `lokinterAPI-main` (Laravel) team
> **Sources:**
> - **[REQ]** `Lokinter_Approved_Implementation_Requirements.pdf` (02 Nov 2026), cited as **REQ §n**
> - **[GUIDE]** "Mobile App & Frontend: Existing Features Upgrade & Preservation Guide", cited as **GUIDE Screen n**
>
> **Companion docs:** `docs/BACKEND_REQUIREMENTS_MOBILE.md` (17 Sep 2026), `docs/BACKEND_GAPS.md`, `docs/WEBSITE_PARITY.md`

The GUIDE says the backend is fully implemented (130 feature tests). The mobile app
does **not** call any of the new endpoints yet, and the GUIDE only names them. It
does not give request or response shapes. This document lists **exactly what the app
needs from each endpoint** so it can be built without guessing.

For each item, the backend team should either:
- ✅ **Confirm.** Reply "matches", or paste one real response.
- ✏️ **Correct.** Give the real key, path or status code, and the app will follow it.
- ❌ **Build.** Use this if the item turns out not to exist yet.

**Ground rules (unchanged from the Sep doc):**
- Do not rename or remove existing keys. Installed builds and the website parse them.
- Key casing: the app reads **camelCase** in responses (`arrivalDate`, `paymentMethod`, `referenceId`).
  Request bodies may be camelCase or snake_case, but say which.
- All new responses use the existing envelope (`{status, message, data}`) that `unwrapData()` reads.
- Errors: `422` for validation, with `errors.{field}[]`. Business-rule refusals need a stable
  machine-readable `code` (see §0.2), not only a translated `message`.

---

## §0. Blocking questions (answer first)

| # | Question | Blocks |
|---|---|---|
| **Q1** | How is a deal classified as local? Can the app trust `location: "LOCAL"` on the deal and the chat post? Or must it be `fromCountry == toCountry == TN`? Does `LOCAL` in another country (e.g. FR→FR) also get COD-only and the TND ledger? | §2, §3, §8 |
| **Q2** | One real `GET /deals/getById/{id}` response for a **local ONGOING** deal, after this update | §3, §4, §5 |
| **Q3** | One real `GET /transporters/ledgers` response, ideally with one ledger in `PAYMENT_REQUIRED` | §8, §9 |
| **Q4** | The settlement payment method for ledgers: Stripe PaymentSheet, Stripe card element (like escrow), bank transfer, or a choice? | §8.3 |
| **Q5** | Where do overdue restrictions show up? In the `/auth/profile` user payload, a separate endpoint, or only as `403` errors? | §9 |
| **Q6** | Is a QR code still valid when it's a plain `deal-details/{referenceId}` link? Old installed builds still render that link. | §4 |

### §0.1 Coordinates

Map pins (REQ §4, §6.2) need numbers. The app will send and read
`pickupLat`, `pickupLng`, `dropoffLat`, `dropoffLng` (decimal degrees, WGS84) next to the
existing text keys `pickupLocation` / `dropoffLocation`. ✏️ Correct these if the names differ.

### §0.2 Stable error codes

The app has to tell these refusals apart. Each one needs a `code` in the error body:

| code | HTTP | When | App reaction |
|---|---|---|---|
| `TRANSPORTER_REQUIRED` | 403 | A non-transporter posts a local trip | Banner and a "Apply for verification" link |
| `TRANSPORTER_CANNOT_REQUEST` | 403 | A transporter posts a `DELIVER` request | Helper text |
| `DEAL_ALREADY_CONFIRMED` | 409 (GUIDE says 400) | A second transporter confirms | "Deal Unavailable" dialog, then refresh |
| `LOCAL_COD_ONLY` | 422 | Stripe or a deposit on a local deal | Should never happen from the app; shows a toast |
| `QR_INVALID` | 422 | Scanned token is revoked, used or from another deal | "Invalid or expired QR" alert |
| `LEDGER_OVERDUE` | 403 | Overdue transporter starts a chat, accepts a deal or posts a trip | Restriction alert with the amount (see §9) |

Today the GUIDE says the app should match on the English message text
(`"already has an active or confirmed deal"`). That breaks in French. Please add `code`.

---

## §1. Posting permissions (REQ §1 · GUIDE Screen 1)

**App today:** no role check. `post_trip_page.dart` lets anyone choose Local, and
`post_request_page.dart` lets transporters post requests.

**App will:** block both cases in the UI using the user payload. The backend must
also reject them (REQ §1: *"Enforce permission checks in backend APIs, not only in the mobile UI"*).

| Endpoint | Rule | Error |
|---|---|---|
| `POST /posts/addNewPost`, `type=TRIP`, `location=LOCAL` | Only approved transporters | `403 TRANSPORTER_REQUIRED` |
| `POST /posts/addNewPost`, `type=DELIVER` | Not approved transporters (local or international) | `403 TRANSPORTER_CANNOT_REQUEST` |
| Same rules on the **edit-post** endpoint | Stops a post being switched to LOCAL by editing it | same |

**User payload the app relies on** (`AuthUser.fromJson`): `isApprovedTransporter`,
`transporterBadge`, `transporterVerificationStatus` (`approved` / `pending` / `rejected` / `none`).
✅ Confirm these are still sent on `/auth/profile` and in the login response.

**Acceptance:** a normal user can post Tunis → Paris (TRIP, INTERNATIONAL) but gets `403` for Tunis → Sousse (TRIP, LOCAL).

---

## §2. Deal agreement form (REQ §2, §3, §4, §5 · GUIDE Screen 2)

**App today:** `POST /deals/addNewDeal` (multipart), from
`deals_repository.dart` `create()`. It sends:

```
senderId, travelerId, postId, wantTo, cost(int), itemEstimatedCost, weight(int),
tripDate(Y-m-d), arrivalDate(ISO UTC), arrivalTime(HH:mm), arrivalAt(ISO UTC),
sdRequired(0|1), itemName?, itemLink?, itemDescription?, receiverName?, receiverPhone?,
paymentMethod ('STRIPE' | 'CASH_ON_DELIVERY'), attachFiles[]
```

### 2.1 Required server behaviour

| Field | Local deal | International deal | Ref |
|---|---|---|---|
| `paymentMethod` | Force `CASH_ON_DELIVERY`. Reject `STRIPE` with `422 LOCAL_COD_ONLY` | unchanged | REQ §2 |
| `sdRequired` | Force `0`. Reject `1` | unchanged | REQ §2 |
| `receiverName` / `receiverPhone` / `receiverCountry` | optional | **optional** (was required) | REQ §3 |
| `pickupLocation` + `pickupLat/Lng` | **required** | optional | REQ §4 |
| `dropoffLocation` + `dropoffLat/Lng` | **required** | optional | REQ §4 |
| `tripDate` | **optional / ignored**. The app will stop sending it | required (unchanged) | REQ §5 |
| `arrivalDate` (full instant) | **required, must be in the future** | required (unchanged) | REQ §5 |
| "arrival ≤ tripDate + 3 days" rule | **skip** (no tripDate) | unchanged | REQ §5 |
| Auto-completion fallback | `arrivalDate + 48h`, only if there's evidence and no dispute | unchanged | REQ §5, §12 |

✏️ Confirm the receiver field is called `receiverCountry`. The app has never sent it, because the
picker only set the phone prefix.

### 2.2 Data for pre-filling (REQ §4, §5)

The app opens the deal form from the chat. `GET /chats/getChatDetails/{userId}`
returns `post` (parsed as `ChatPostContext`). Right now the app reads only
`id, type, wantTo, location, fromCity/Country, toCity/Country, beforeDate, user.id, userRole`.

The `post` block must **also** include:

```json
"post": {
  "location": "LOCAL",
  "pickupLocation": "Avenue Habib Bourguiba, Tunis",
  "pickupLat": 36.8008, "pickupLng": 10.1800,
  "dropoffLocation": "Port El Kantaoui, Sousse",
  "dropoffLat": 35.8925, "dropoffLng": 10.5950,
  "beforeDate": "2026-11-10T15:00:00Z"
}
```

- `type=DELIVER` (a request): the app pre-fills pickup, drop-off and arrival from these fields.
- `type=TRIP` (contacting a transporter directly): the app makes the sender pick both points by hand.
- `beforeDate` must be a parsable date for pre-filling the arrival. Today it sometimes comes as a
  display label (`"Available upon request"`). Please send a raw `beforeDateRaw` (ISO, or null)
  next to the label.

### 2.3 Sender fee display (GUIDE Screen 2.1.4)

The app will show "Sender fee: 0.000 TND" on local deals as fixed text. No API is needed
unless the backend wants to own that value.

---

## §3. Deal detail payload additions (REQ §2–§6, §12 · GUIDE Screens 3–6)

`GET /deals/getById/{id}` (and `agreementDetails`, which the app merges in) must add:

| Key | Type | Purpose |
|---|---|---|
| `location` | `"LOCAL"` / `"INTERNATIONAL"` | already read; ✅ confirm it's still sent |
| `currency` | `"TND"` / `"USD"` / … | price display |
| `pickupLocation`, `pickupLat`, `pickupLng` | string, number | map pin and address |
| `dropoffLocation`, `dropoffLat`, `dropoffLng` | string, number | map pin and address |
| `deliveryQrToken` | string or null | §4. **Sender only**, and only while `ACCEPTED`/`OUTGOING`. Must be `null` for the transporter, or they could complete the deal alone |
| `trackingAvailable` | bool | true only while `OUTGOING` **and** the viewer is the sender, the assigned transporter or an admin (REQ §6.1) |
| `platformFee` | object or null | §7 |

`receiverName` / `receiverPhone` may be null from now on. The app already handles that.

---

## §4. Single-use QR handover (REQ §3 · GUIDE Screens 4, 5)

**App today:**
- The sender's QR encodes `{webBaseUrl}/deal-details/{referenceId}` (`Deal.confirmationLink`). That's fixed and reusable.
- After a scan, the transporter calls `POST /deals/markAsCompleted/{referenceId}` with
  `completion_type=QR_SCAN`, after uploading the delivery video to `POST /deals/{referenceId}/uploadDeliveryVideo`.

### 4.1 What the QR encodes

✏️ **Decide and confirm one:**
- **(a)** The raw `deliveryQrToken`, or
- **(b)** a URL `{webBaseUrl}/deal-details/{referenceId}?t={deliveryQrToken}`, so a recipient
  without the app still sees the public page (current behaviour).

The app recommends **(b)**. It keeps the web confirmation page working, and the scanner can pull
both `referenceId` and `t` out of the URL.

### 4.2 Regenerate (revoke)

```
POST /deals/{id}/regenerate-qr          (sender only)
→ 200 { data: { deliveryQrToken: "…", regeneratedAt: "ISO" } }
→ 403 not the sender · 422 deal not ACCEPTED/OUTGOING
```
The old token must stop working right away.

### 4.3 Confirm delivery by token

```
POST /deals/{id}/confirm-qr-delivery    (assigned transporter only)
body: { qr_token: "…" }
→ 200 { data: <deal> }           deal now COMPLETED (or whatever the existing next state is)
→ 422 { code: "QR_INVALID" }     revoked / used / wrong deal
```
✏️ Answer these:
1. Is the **delivery video still required** before this call, as with `uploadDeliveryVideo` today? Should the app keep uploading it first?
2. Does this endpoint **replace** `markAsCompleted` with `QR_SCAN`, or should both work? (Old builds still call `markAsCompleted`.)
3. Does `SENDER_CONFIRMATION` through `markAsCompleted` still work unchanged?

---

## §5. Track My Order (REQ §6 · GUIDE Screens 6, 7)

### 5.1 Transporter sends a position

```
POST /deals/{id}/tracking/location      (assigned transporter, deal OUTGOING only)
body: {
  "latitude": 36.80, "longitude": 10.18,
  "accuracy": 12.5,            // metres, nullable
  "speed": 8.3,                // m/s, nullable
  "heading": 270,              // degrees, nullable
  "recordedAt": "2026-11-09T10:35:12Z"   // device time of the GPS fix
}
→ 201
→ 403 not the transporter
→ 409 deal is not OUTGOING   ← the app stops sending when it sees this
```

**Batch upload (offline queue, GUIDE Screen 7.3).** The app queues positions while offline.
Please accept either:
- `body: { points: [ {latitude, longitude, accuracy, speed, heading, recordedAt}, … ] }` on the same endpoint, or
- a separate `POST /deals/{id}/tracking/locations/batch`.

✏️ Which one? Also give the maximum batch size, and confirm that points are ordered by `recordedAt`, not by arrival time.

**Interval:** REQ §6.3 says "configurable". Please return it so the app doesn't hard-code it:
`trackingIntervalSeconds` in the deal detail or the tracking response (GUIDE suggests 15–30 s).

### 5.2 Sender, transporter or admin reads it

```
GET /deals/{id}/tracking
→ 200 { data: {
    "dealStatus": "OUTGOING",
    "trackingActive": true,
    "connectionStatus": "LIVE",          // LIVE (<2 min) | DELAYED (2–10 min) | UNAVAILABLE (>10 min / none)
    "lastLocation": {
      "latitude": 36.80, "longitude": 10.18, "accuracy": 12.5,
      "heading": 270, "speed": 8.3,
      "recordedAt": "2026-11-09T10:35:12Z",
      "receivedAt": "2026-11-09T10:35:14Z"
    },                                    // null if no position yet
    "pickup":  { "label": "…", "lat": 36.80, "lng": 10.18 },
    "dropoff": { "label": "…", "lat": 35.89, "lng": 10.59 },
    "route": null,                        // only when backed by real routing data (REQ §6.2). Never invented
    "eta": null
  } }
→ 403 not a participant / admin
→ 200 with trackingActive:false and lastLocation:null once COMPLETED / CANCELLED
```

**Live updates.** The app already uses Pusher for chat. Please confirm one of:
- a private channel `private-deal.{id}` with a `TrackingLocationUpdated` event (payload = `lastLocation` + `connectionStatus`), or
- polling only. The app will poll `GET /tracking` every `trackingIntervalSeconds` while the map is open.

**Stop signal.** When a deal leaves `OUTGOING`, the transporter app needs to stop the
background service even if it's closed. Please send a **silent FCM data push**
`{type: "TRACKING_STOP", dealId}` on completion or cancellation. The `409` above is the fallback.

**Acceptance (REQ §6):** no positions accepted before pickup evidence or after the deal ends. A non-participant gets `403`.
Losing tracking never cancels or completes a deal.

---

## §6. Confirmation concurrency lock (REQ §2 · GUIDE Screen 3)

**App today:** the traveler accepts with `POST /deals/changeStatus/{id}` and `status=ACCEPTED`.
Errors show as a generic toast.

✏️ Confirm:
1. Which endpoint is the lock on: `changeStatus` with `ACCEPTED`, `addNewDeal`, or a new `confirmDeal`? The GUIDE calls it `api.confirmDeal(dealId)`, which the app doesn't have.
2. The error body includes `code: "DEAL_ALREADY_CONFIRMED"` (§0.2).

---

## §7. Fee on deal completion (REQ §7, §8, §11 · GUIDE Screen 8)

The deal detail (and the `markAsCompleted` / `confirm-qr-delivery` response) should carry:

```json
"platformFee": {
  "applies": true,                      // false for ordinary travelers → app shows "0.00 (exempt)"
  "status": "FINALIZED",                // PENDING (dispute/verification open) | FINALIZED | WAIVED | REVERSED
  "ledger": "LOCAL",                    // LOCAL | INTERNATIONAL
  "currency": "TND",
  "amount": "0.900",                    // string, keeps the 3 TND decimals exact
  "tier": { "index": 1, "from": 1, "to": 10, "rate": "0.900" },
  "period": { "type": "CALENDAR_MONTH", "count": 5 },   // or ROLLING_90_DAYS
  "nextTier": { "rate": "0.800", "dealsRemaining": 5 }  // null at the top tier
}
```

- Only the **transporter** on the deal sees `platformFee`. The sender gets `null`.
- Amounts are **strings**, so `0.900` doesn't become `0.9` and USD doesn't pick up float errors.
- `PENDING` must be shown while a dispute or verification is open (REQ §12). The app shows "Fee pending".

---

## §8. Dual ledgers (REQ §9, §10 · GUIDE Screen 9)

### 8.1 Summary

```
GET /transporters/ledgers     (approved transporters; others → 403 or { ledgers: [] })
→ 200 { data: { ledgers: [
  {
    "type": "LOCAL",
    "currency": "TND",
    "balance": "12.400",                 // unpaid, not frozen
    "frozenAmount": "0.000",             // covered by an open payment request
    "threshold": "15.000",
    "status": "ACTIVE",                  // ACTIVE | PAYMENT_REQUIRED | OVERDUE
    "paymentRequest": null,              // see below when PAYMENT_REQUIRED/OVERDUE
    "loyalty": { "period": "CALENDAR_MONTH", "count": 18, "currentRate": "0.800",
                 "nextTier": { "rate": "0.700", "dealsRemaining": 13 },
                 "periodEndsAt": "2026-11-30T23:00:00Z" },
    "canPayVoluntarily": true
  },
  {
    "type": "INTERNATIONAL",
    "currency": "USD",
    "balance": "0.00",
    "frozenAmount": "25.85",
    "threshold": "25.00",
    "status": "PAYMENT_REQUIRED",
    "paymentRequest": {
      "id": 41,
      "amount": "25.85",
      "createdAt": "2026-11-05T09:00:00Z",
      "dueAt": "2026-11-12T09:00:00Z",   // createdAt + grace period (7 days, admin-extendable)
      "extended": false
    },
    "loyalty": { "period": "ROLLING_90_DAYS", "count": 11, "currentRate": "2.15",
                 "nextTier": { "rate": "1.99", "dealsRemaining": 10 } },
    "canPayVoluntarily": false
  }
] } }
```

The app shows the countdown from `dueAt`. It never works out the deadline itself.

### 8.2 Entries (history)

```
GET /transporters/ledgers/{type}/entries?page=&status=   (type = LOCAL | INTERNATIONAL)
→ list of { id, createdAt, amount, kind: FEE|ADJUSTMENT|WAIVER|REVERSAL|PAYMENT,
            status: UNPAID|FROZEN|PAID|REVERSED, paymentRequestId?, note? }
```
Each entry's `dealId` / `referenceId` is fine to show to the transporter in the app.
REQ §15 only keeps deal references off the **invoice**.

### 8.3 Settlement

```
POST /transporters/ledgers/{currency}/initiate-settlement
   ({currency} = TND | USD, as in GUIDE. ✏️ or {type} = LOCAL | INTERNATIONAL?)
body: { mode: "REQUIRED" | "VOLUNTARY" }
→ 200 { data: {
    settlementId: 77,
    amount: "25.85", currency: "USD",
    method: "STRIPE",                       // STRIPE | BANK_TRANSFER
    clientSecret: "pi_…_secret_…",          // when STRIPE
    paymentIntentId: "pi_…",
    bankDetails: { iban, bic, beneficiary, reference }  // when BANK_TRANSFER
} }
```

Then, the same two steps as escrow today (`confirm-payment`):

```
POST /transporters/ledgers/settlements/{settlementId}/confirm   body: { paymentIntentId }
→ 200 { data: <updated ledger> }       restrictions lifted in the same response
```

✏️ Answer **Q4**. Also: can **TND** be paid by Stripe at all? Stripe doesn't settle in TND.
If TND is bank or cash only, return `method: BANK_TRANSFER` and the app will show the details plus
"Awaiting admin verification" (`status: PENDING_VERIFICATION`).

Calling `initiate-settlement` twice must return the **same** open settlement, not a new
one (REQ §10.1.5, no double collection).

---

## §9. Overdue restrictions (REQ §10.2 · GUIDE Screen 10)

The app needs the restriction state **before** the user taps, so it can grey out
buttons. A 403 after the tap isn't enough. Add this to the `/auth/profile` user payload:

```json
"feeRestrictions": {
  "restricted": true,
  "blocked": ["NEW_CHAT", "ACCEPT_DEAL", "POST_TRIP"],
  "overdue": [ { "type": "LOCAL", "currency": "TND", "amount": "15.400", "dueAt": "…" } ]
}
```

Server rules:

| Action | Overdue | Endpoint(s) |
|---|---|---|
| Start a new chat | **403 `LEDGER_OVERDUE`** | ✏️ which endpoint creates a chat: first `sendMessage` to a new peer? |
| Accept a deal | **403 `LEDGER_OVERDUE`** | the lock endpoint from §6 |
| Post a trip | **403 `LEDGER_OVERDUE`** | `POST /posts/addNewPost` with `type=TRIP` |
| Messages in an **existing** chat, ongoing deal actions, pickup or delivery video, QR completion, disputes, ledger, invoices, payment | **never blocked** | — |

**Lifting restrictions:** once payment is verified, send a push `{type: "FEE_RESTRICTION_LIFTED"}`
(FCM is already wired in `push_service.dart`). The app then refreshes the profile without a restart.

---

## §10. Invoices (REQ §15.1 · GUIDE Screen 11)

```
GET /transporters/invoices?page=
→ list of {
    id, number: "INV-2026-TND-00001", issuedAt, currency,
    subtotal, tax, total, status: "PAID",
    paymentReference, paidAt,
    description: "Lokinter Platform Service & Operating Fees"
  }

GET /transporters/invoices/{id}/download
→ 200 application/pdf    (with Authorization header. ✏️ or a signed URL valid ~5 min?)
```

- No deal numbers, customer names or item contents in the list or the PDF (REQ §15.1).
- One invoice per confirmed settlement. Retries must not create a duplicate.

The app prefers a **signed URL** (`{ url, expiresAt }`), so the PDF can open in the system
viewer through `url_launcher` with no extra package.

---

## §11. Push notifications (FCM data `type`)

The app's notification router already switches on `type`. These are the new ones it will handle:

| `type` | To | Payload | App action |
|---|---|---|---|
| `TRACKING_STOP` | transporter | `dealId` | stop GPS service (silent) |
| `LEDGER_PAYMENT_REQUIRED` | transporter | `ledgerType, amount, currency, dueAt` | open ledgers |
| `LEDGER_PAYMENT_REMINDER` | transporter | same | open ledgers |
| `LEDGER_OVERDUE` | transporter | same | open ledgers, refresh restrictions |
| `FEE_RESTRICTION_LIFTED` | transporter | — | refresh profile |
| `LEDGER_PAYMENT_CONFIRMED` | transporter | `invoiceId` | open invoice |
| `QR_REGENERATED` | transporter on that deal (optional) | `dealId` | refresh deal |

✅ Confirm the names, or send the list the backend already uses.

---

## §12. Out of scope for this doc

These are backend or admin only. The app has no part in them, and they're listed here only for completeness:
REQ §7/§8 tier maths and rolling windows · §10.1 freezing and threshold triggers · §12 anti-abuse
and immutable entries · §13 admin finance controls · §14 admin notifications and Action Center ·
§15 invoice generation and tax. The app only displays what the endpoints above return.

---

## §13. Checklist for the backend reply

| § | Item | ✅ / ✏️ / ❌ |
|---|---|---|
| 0 | Q1–Q6 answered, error `code`s added | |
| 1 | Post permission checks on add **and** edit | |
| 2.1 | `addNewDeal` local rules (COD, no SD, no tripDate, pickup/drop-off required, future arrival) | |
| 2.1 | Receiver fields optional everywhere | |
| 2.2 | Chat `post` block carries pickup/drop-off, coordinates and `beforeDateRaw` | |
| 3 | Deal detail: coordinates, `deliveryQrToken` (sender only), `trackingAvailable`, `platformFee` | |
| 4 | QR format decided, `regenerate-qr`, `confirm-qr-delivery`, compatibility with old `markAsCompleted` | |
| 5 | `tracking/location` (+ batch), `GET tracking`, interval, Pusher channel or polling, `TRACKING_STOP` | |
| 6 | Lock endpoint plus `DEAL_ALREADY_CONFIRMED` | |
| 7 | `platformFee` object | |
| 8 | `ledgers`, `entries`, `initiate-settlement`, `confirm`, TND payment method | |
| 9 | `feeRestrictions` in profile, 403s, lift push | |
| 10 | `invoices` list and download | |
| 11 | Push `type` names | |
