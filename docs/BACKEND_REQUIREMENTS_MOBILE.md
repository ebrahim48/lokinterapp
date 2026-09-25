# Lokinter Backend — Requirements for the Mobile Fix List

> **Written:** 17 Sep 2026
> **Source:** client fix list "LOKINTER Mobile App — Required Fixes & Updates" (points 1–7)
> **Audience:** `lokinterAPI-main` (Laravel) team
> **Companion docs:** `docs/BACKEND_GAPS.md` (Jul 2026 API findings), `docs/WEBSITE_PARITY.md`
> **Cross-reference:** backend audit "Missing Specification & Feature Audit" (re-checked 17 Sep 2026)

This document covers **only what the backend must change** so the mobile app can
deliver the client's fix list. App-side work is tracked separately.

Every item states: *why it is needed → what the app does today → what the API must
return/accept → acceptance criteria*. Field names are the ones the app already
parses; renaming them breaks installed builds.

Website (`lokinter-ui-main`) contracts stay frozen — nothing here renames or
removes an existing key.

---

## §0. Blocking questions (answer these first)

These four answers unblock app work that is otherwise guesswork.

| # | Question | Why it blocks |
|---|---|---|
| **Q1** | Paste the actual `user` JSON block from one `GET /posts/getPosts` response. | The app reads `isTransporter`, `transporterVerificationStatus`, `isFeaturedTransporter`, `transporterVisibilityStatus`. The backend audit mentions `isApprovedTransporter` / `transporterBadge`. If those are the real keys, **no transporter badge renders anywhere in the app today** and §1.3 below is the real fix, not the eager-load. |
| **Q2** | Does `categoryIds` accept a **JSON-encoded string** (`"[1,2]"`), or must it be repeated `categoryIds[]` fields? | The app posts multipart, so the value arrives as a string. A strict Laravel `array` rule 422s it. |
| **Q3** | What are the exact `/wallet/` keys for **pending withdrawal** and **on-hold/dispute** amounts? The Wise reserve already exists server-side, so the data exists. | The 4-bucket wallet screen (client point 4.2) cannot be built without them. |
| **Q4** | Reset password: **code in the email**, or **reset link + deep link**? | Two completely different implementations. See §6. |

---

## §1. Corrections / confirmations on the existing backend audit

### 1.1 Multiple categories — works, one risk (audit item #1 ✅)

The app already sends both shapes on `POST /posts/addNewPost`:

```
categoryIds: "[1,2]"     ← JSON-encoded string inside multipart/form-data
categoryId:  1           ← legacy single value, kept for older builds
```

and reads back `categoryTitles` / `categoryIds`, falling back to
`categoryTitle` / `categoryId`.

**Action:** answer **Q2**. If validation is a strict `array` rule, either
`json_decode` the string (the way `rejectedCategoriesIds` is already handled) or
tell us and the app will switch to repeated `categoryIds[]` keys.

### 1.2 Traveler profit — do NOT make it required yet (audit item #2 / #4)

Current app behaviour:

* sends `traveler_profit` (snake_case) — accepted by the current rules
* reads `travelerProfit` back — matches
* **profit is optional in the app form; there is no client-side validation**

**Making `travelerProfit` required for `DELIVER` will start returning 422 to every
installed build** for any request posted without a profit.

**Required sequence:**

1. App ships the field as required + validation, and a forced-update/soft-prompt.
2. Only then the backend flips `nullable` → `required_without` for DELIVER.

**Open product question:** the app form also collects a **currency** next to the
profit, which is currently dropped because the API has no field for it. A profit
of "50" from a Tunisian user and "50" from a French user are stored identically
today. Either add `travelerProfitCurrency` (ISO-4217), or confirm that profit is
always USD and we remove the selector from the app.

### 1.3 Transporter badge columns — wider than `getPostById` (audit item #7)

The audit correctly identifies `getPostById` eager-loading only
`user:id,full_name,kyc_status`. The same columns are needed in **every** resource
that embeds a user, because the client asks for the badge "everywhere an approved
transporter is displayed":

| Endpoint / resource | Used by the app for |
|---|---|
| `GET /posts/getById/{id}` | post details header |
| `GET /posts/getPosts` | search + home cards *(already loaded)* |
| `GET /home/mobile` | recommended rail |
| `GET /chats/getAllChats` | chat inbox rows |
| `GET /chats/getChatDetails/{id}` | chat conversation header |
| `GET /deals/getById/{id}`, `GET /deals/getAllDeals` | deal counterpart |
| `GET /rates/getUserInfo` | public profile / reviews screen |
| **new** `GET /transporters/recommended` | §2.1 popup |

Columns: `transporter_verification_status`, `is_featured_transporter`,
`transporter_visibility_status` (+ whatever backs `isTransporter`).

**Badge rule the client stated:** only `transporterVerificationStatus == 'approved'`
earns the badge. A pending or rejected application must not.

### 1.4 Backend French is a hard dependency for app French (audit item #6)

The app sends `X-Lang` and `Accept-Language` on **every** request and displays the
envelope's `message` string verbatim in its success/error toasts. Any leftover
hardcoded English in a controller, console command, FCM payload or WhatsApp
template **appears untranslated inside the app UI**, and the app cannot fix it.

Scope requested by the client: buttons, pop-ups, notifications, error/success/
validation messages, wallet & payment messages, transporter and dispute sections,
system chat messages, and **backend/API-generated messages**.

### 1.5 Withdrawal reserve — needed for all methods (audit item #5)

Wise already reserves. The client's point 4.6 asks for the same on every method.
More importantly, the app currently has **no way to read the reserved amount** —
see §4.2.

---

## §2. Transporter section

### 2.1 🔴 NEW — Recommended transporters for the post-request popup (client 1.3)

**Need:** immediately after a delivery request is posted, the app shows a popup of
transporters the sender can start a chat with. Nothing like this exists today —
the app has no endpoint that lists transporters at all.

**Proposed contract:**

```
GET /api/v1/transporters/recommended?country=TN&postId=123&limit=10
```

Filters (all mandatory, applied server-side):

* country matches the relevant country (see §2.2 for the definition)
* `transporter_verification_status = 'approved'`
* has an **active** Increase-Visibility package
  (`is_featured_transporter = true` AND `transporter_visibility_status = 'active'`)
* excludes the requesting user

```json
{
  "code": 200, "status": true, "message": "...",
  "data": {
    "totalRecords": 2,
    "list": [
      {
        "id": 42,
        "name": "Triple R Logistics",
        "imageUrl": "https://api.ssh.bd/api/v1/media/.../stream",
        "country": "TN",
        "rate": 4.7,
        "isTransporter": true,
        "transporterVerificationStatus": "approved",
        "isFeaturedTransporter": true,
        "transporterVisibilityStatus": "active",
        "completedDeliveries": 12
      }
    ]
  }
}
```

**Acceptance criteria**

* `id` is the **user id** the app can pass to `GET /chats/getChatDetails/{id}` to
  open a chat directly from the popup.
* An empty `list` is returned when nobody qualifies — the app then shows no popup
  at all (the client explicitly asked for no empty popup).
* Never returns unapproved, unpaid, or expired-package transporters.

### 2.2 🔴 Country-based recommendations (client 1.6)

**Need:** "Tunisia user → Tunisia-related travelers/transporters. France user →
France-related. Users from unrelated countries should not appear."

Today `GET /home/mobile` returns `recommendedTravelers` unfiltered, and the app
applies no country filter.

**Required:**

* `GET /home/mobile` filters `recommendedTravelers` (and any recommended
  transporters) by the authenticated user's registered country, or accepts an
  explicit `?country=XX` override.
* Same rule applied to §2.1.

**Please define "relevant country" explicitly** — we assume a post matches when
`fromCountry` **or** `toCountry` equals the user's registered country, and a
transporter matches when the country is in their `operatingCountries`. Confirm or
correct, because the app will show whatever this returns.

### 2.3 🟠 Increase Visibility — Stripe result handling (client 1.1)

The app already runs the card step: `POST /visibility/transporter/subscribe` →
native Stripe sheet on `clientSecret` → `POST /visibility/transporter/confirm-subscription`.

**Confirm / provide:**

1. `subscribe` always returns `clientSecret` **and** `paymentIntentId` when a card
   step is needed, and returns neither when it settled server-side.
2. **Cancelled payment:** a way to release or expire the pending subscription when
   the user dismisses the sheet — either an explicit
   `POST /visibility/transporter/cancel-subscription {paymentIntentId}` or a
   documented server-side expiry. Today a dismissed sheet may leave a dangling
   pending row.
3. **Failed payment:** `confirm-subscription` must return a non-2xx envelope with a
   human message when the intent did not succeed, so the app does not announce an
   activation that did not happen.
4. The package is activated **only** after Stripe confirms — never on
   `subscribe` alone.
5. Eligibility: should the subscription be restricted to **approved transporters
   only**? The app currently offers it to any account. Product decision needed.

### 2.4 Become a Transporter — status + notifications (client 1.2)

Mostly an app-side fix (the button must stay visible and disabled per status).
Backend only needs to guarantee, on `GET /auth/user`:

* `transporterVerificationStatus` ∈ `none | pending | approved | rejected`
  (the app treats a missing value / `"none"` as "never applied")
* `transporterRejectionReason` populated on rejection
* a **rejected** application can be resubmitted through
  `POST /transporters/request-verification` (no "already applied" block)
* the existing application-submitted and status-change notifications keep firing

### 2.5 Admin — Accepted Transporters section (client 1.5)

Admin dashboard work, listed here for completeness. Columns requested: user name /
user id, country, transporter status, approval date, badge/status, Increase-
Visibility status — filterable/separable from normal users.

---

## §3. Notifications

### 3.1 🔴 Country-based trip & request alerts (client 2.1)

**Required behaviour:** when someone posts a Trip or Delivery Request relevant to
my country, I get **exactly one** notification, subject to:

* `notifyTrips` ON/OFF respected for trips
* `notifyRequests` ON/OFF respected for delivery requests
* **the creator never receives their own notification**
* country relevance per §2.2

**App side:** the app already reads/writes
`GET|POST /notifications/preferences` with
`notifyPushEnabled`, `notifyTrips`, `notifyRequests`, `notifyMarketing`,
`notifyCountries`. Please confirm `notifyCountries` is persisted and actually used
for targeting — the app will start sending it.

### 3.2 🔴 Duplicate deal-status notifications (client 2.2)

Every deal status change currently produces **two** notifications per recipient
(client screenshot attached to the fix list).

**Required:** one notification per status change per relevant user. Please check
for a double dispatch — e.g. both a model observer and a controller call firing,
or a DB notification plus an FCM record both being listed by
`GET /notifications/getNotifications`.

**Acceptance:** change a deal status once, call
`GET /notifications/getNotifications` for each participant → exactly one new row
each.

---

## §4. Wallet & withdrawals

### 4.1 🔴 Pickup-video-style timeouts aside, wallet reads must be parseable

`GET /wallet/payout-methods` — the app's "Withdrawal Methods" screen currently
**loads forever** for the client.

**Required:**

* `isDefault` must be a real JSON **boolean** (`true`/`false`), not `0`/`1` or
  `"1"`. An integer there throws a type error in the app that the current error
  handler cannot catch, which is the most likely cause of the infinite spinner.
* The payload must always be `data.list` (array), even when empty.
* Return a proper error envelope (not an HTML 500) on failure, so the app can show
  its retry state.

*(The app is being hardened to survive bad types regardless, but the contract
should be correct.)*

### 4.2 🔴 Four balance buckets (client 4.2 + 4.6)

Today `GET /wallet/` gives the app `available`, `totalPending`,
`lifetimeEarnings`, `currency`, `hasStripeConnect`, plus
`potentialEarningsList[]` and `disputeHistory[]`. There is **no field for money
reserved by a pending withdrawal**, so the app cannot display the client's
requested breakdown.

**Required additions** (names negotiable — answer **Q3**):

```json
"available":         120.00,
"pendingEarnings":    80.00,
"onHoldDispute":      45.00,
"pendingWithdrawal":  80.00,
"currency": "USD"
```

**Reserve semantics (client 4.6):** available 100 → request 80 → available 20,
pendingWithdrawal 80. On reject/cancel/fail → the 80 returns to available.
Currently Wise reserves but **Stripe and PayPal debit immediately** — please
align all three, or tell us so the app can label them differently.

### 4.3 🔴 Withdrawal validation is the backend's job (client 4.5 + 4.8)

The app will add client-side checks, but the server must be authoritative and
reject:

* amount **>** available balance
* amount **= 0**, negative, or non-numeric
* a second pending request while one is open (duplicate prevention)
* replayed/duplicate transactions (idempotency key or equivalent)

Each rejection should return a 422 with a translated `message` — the app displays
it verbatim.

### 4.4 🟠 Transaction detail fields (client 4.1)

The client complains about "a long/random technical code" shown to users. That is
the deal reference the app prints because it is the only deal identifier in the
row.

**Required per transaction row:**

```json
{
  "id": 91,
  "type": "credit",            // credit|debit|refund|reserve|release|...
  "status": "completed",       // explicit, human-mappable
  "amount": 50.00,
  "dealId": 123,               // numeric id, shown as "Deal #123"
  "dateTime": "2026-09-14 10:22:00",
  "description": "Delivery payout"
}
```

The long `dealRef` may stay in the payload (used for QR/deep links) but must not
be the only identifier — the app will stop displaying it.

### 4.5 🟠 Wise payout fee (client 4.4)

`POST /wallet/payout-requests/quote` currently returns `fee: 0` for Wise, which the
app renders as "Fee: 0 USD" — the client says this is wrong.

**Required:** for Wise return either an explicit flag or a message, e.g.

```json
{ "amount": 80, "feeKnown": false, "feeAmount": null, "netAmount": null,
  "currency": "USD",
  "message": "Wise transfer fees may apply and will be deducted from the withdrawal amount." }
```

The app will show that sentence instead of a zero fee.

### 4.6 Admin withdrawal view + audit log (client 4.7 + 4.8)

Admin work: user, requested amount, available balance, method/details, request
date, status (`Pending → Processing → Paid / Rejected / Failed`). On a successful
Wise payout: mark **Paid**, keep the row in wallet history, and deduct from the
balance. All manual admin financial actions logged.

---

## §5. Deals & disputes

### 5.1 🔴 Pickup video — the core bug (client 3)

**Reported:** pickup video fails at any duration (5s/10s/20s/30s); the chat message
says the item was picked up, but the deal status stays ACCEPTED.

**What the app does:** `POST /deals/{id}/uploadPickupVideo` (multipart `video`),
then on success `POST /deals/changeStatus/{id} {status: "OUTGOING"}`.

**Most likely cause (app side, being fixed):** the app's HTTP client has a 30s
receive timeout with no override for uploads. If the server takes longer than 30s
to process the video, the app throws — so `changeStatus` never runs — while the
server has already stored the video and posted the "picked up" chat message. That
matches the reported symptom exactly.

**Backend actions:**

1. Tell us the **realistic worst-case processing time** for a 30s video, so the app
   sets a correct timeout.
2. Preferably **flip the deal to OUTGOING server-side on a successful upload**, and
   return the updated deal in the response. Then the two-step client flow
   disappears and the status can never diverge from the video.
3. **Do not post the "item picked up" system chat message or notification unless
   the status actually changed.** This is what makes the failure look like a
   success to the user.
4. On failure return a clean error envelope (no HTML 500) so the app can show
   "upload failed — retry" and keep the status unchanged.
5. Confirm the accepted max file size / duration / mime types, and return 422 with
   a clear message when exceeded.

**Acceptance:** upload fails → status stays ACCEPTED, no chat message, no
notification, app shows an error with retry. Upload succeeds → status is
Ongoing/Picked-Up, exactly one system message and one notification.

### 5.2 🔴 Realtime deal status + chat (client 5.1)

The app subscribes to Pusher channels `private-chats.{me}`,
`private-chatRoom.{chatId}` and `private-notifications.{me}`. **There is no deal
channel**, so a status change made by one party reaches the other only on a manual
refresh — this is the "significant delay" the client reports.

**Required:** broadcast deal changes, e.g.

```
channel: private-deals.{userId}        (both participants)
event:   deal.status
payload: { dealId, referenceId, status, updatedAt }
```

Fired on: accept, reject, cancel, pickup/OUTGOING, completed, dispute opened,
dispute resolved.

**Also confirm** `/broadcasting/auth` works with the Sanctum bearer token for all
three existing channels. If auth fails the app silently degrades to a 15-second
poll, which would also explain the chat lag.

### 5.3 🟠 Multiple dispute proof images (client 5.2)

`POST /disputes/deal/{id}` currently accepts a single `attachment`.

**Required:** accept `attachments[]` (multipart, multiple files), keep single
`attachment` working for older builds, and return all of them in the dispute
record. Please state the max count and per-file size.

### 5.4 🔴 Block "Mark as completed" during a dispute (client 5.3)

Reported: after a dispute is opened, the sender sees "Mark Deal as Completed"
again — and clicking it **closes the dispute automatically**.

The app is removing the button. **The backend must also refuse it:**

* `POST /deals/markAsCompleted/{referenceId}` returns 422 while a dispute is open
  on that deal.
* Completing a deal must **never** implicitly resolve a dispute. A dispute closes
  only through the proper resolution process.

### 5.5 🟠 The dispute report must stay reachable (client 5.4)

Reported: after opening a dispute the user cannot find the submitted report in the
Disputed Deals section.

**Required:**

* `GET /disputes/deal/{id}` returns the record for **any** deal status, not only
  while the deal is `DISPUTED`.
* `GET /deals/getById/{id}` includes a `dispute` object (reason, description,
  attachments, status, admin decision) whenever one exists.
* A deal with an open dispute is returned by
  `GET /deals/getAllDeals?status=DISPUTES` — please confirm the exact status
  string the API expects and what it does to a deal that was already COMPLETED
  when the dispute was filed. If such a deal stays `COMPLETED`, the app has no way
  to list it under Disputes.

---

## §6. Reset password (client 6)

Reported: the emailed reset link does not work, and the page asks for a
verification code even though the email is link-based — two flows mixed.

The app today implements the **code** flow end to end:
`POST /auth/forgotPassword {email}` → user types the code →
`POST /auth/resetPassword {email, token, password}`.

**Two options — pick one (Q4):**

| Option | Backend work | App work |
|---|---|---|
| **A. Code in the email** *(recommended)* | Put the actual code/token in the email body; make sure `resetPassword` accepts it; stop sending the link, or make the link a plain fallback. | **None** — only copy changes. |
| **B. Reset link + deep link** | Make the web reset page work end to end; agree a deep-link scheme/universal link so the link can open the app. | New deep-link plumbing, new screen flow, iOS/Android association files. |

Either way: **do not mix the two flows in the same email.**

---

## §7. Priority summary

| Priority | Items |
|---|---|
| 🔴 **Blocker for the client's list** | §2.1 recommended-transporters endpoint · §2.2 country filtering · §3.1 country alerts · §3.2 duplicate notifications · §5.1 pickup video · §5.2 realtime deals · §5.4 markAsCompleted guard · §4.1 payout-methods contract · §4.2 balance buckets · §4.3 withdrawal validation · §6 reset password decision |
| 🟠 **Important** | §1.3 badge columns everywhere · §2.3 Stripe cancel/fail path · §4.4 transaction fields · §4.5 Wise fee · §5.3 multi-image disputes · §5.5 dispute retrieval |
| 🟡 **Sequenced / product** | §1.2 required traveler profit (app first) · profit currency · §2.5 + §4.6 admin screens · §1.4 remaining French strings |

---

## §8. Contracts the app depends on — do not change

Renaming or removing any of these breaks installed builds:

* `travelerProfit` (read), `traveler_profit` (write), `remainingWeight`
* `categoryId` / `categoryTitle` **and** `categoryIds` / `categoryTitles`
* Badge flags: `isTransporter`, `transporterVerificationStatus`,
  `isFeaturedTransporter`, `transporterVisibilityStatus` — **pending Q1**
* `GET /auth/user`: `identityVerified`, `phoneVerified`, `kycStatus`,
  `subscription{status,endDate}`, `successfulDeliveriesCount`,
  `hasNoDisputesOnCompletedDeliveries`, `operatingCountries`,
  `transporterRejectionReason`
* Deal role flags `isSender` / `isTraveler` / `userRole`
* Envelope shape `{code, status, message, data}` with lists under `data.list`
* Escrow two-step: `create-payment`/`confirm-payment`,
  `create-guarantee`/`confirm-guarantee` returning
  `clientSecret` + `paymentIntentId`
* `X-Lang` / `Accept-Language` honoured on every endpoint
