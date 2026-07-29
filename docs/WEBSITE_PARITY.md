# Website ↔ App Parity Report

Compared against `lokinter-ui-main` (Angular web app) + `lokinterAPI-main`
(Laravel API) on 2026-07-21. This documents what was brought over to the
app, where the app intentionally has MORE than the website, and the few
places left different on purpose.

---

## 1. Implemented in this pass (website had it, app didn't)

| Area | What was added |
|---|---|
| **Escrow payments** | In-app Stripe payment sheet for the sender escrow hold and the traveler security-deposit hold (`create-payment/confirm-payment`, `create-guarantee/confirm-guarantee`). Previously the app showed a raw URL dialog that couldn't complete payment. Fee breakdown (item / profit / Lokinter fee / total) shown before the card sheet. |
| **Dispute creation** | Full "Open a dispute" flow on OUTGOING and COMPLETED deals: contextual reasons from `/disputes/reasons`, dispute-window countdown, description, photo evidence (required for ITEM_DAMAGED / WRONG_ITEM). |
| **Deal QR code** | Sender sees a QR on OUTGOING deals encoding the website's public `deal-details/{referenceId}` page, so the receiver can scan → confirm delivery. |
| **Phone verification** | WhatsApp OTP flow on Basic info (`sendPhoneOtp` / `verifyPhoneOtp`), 2-step sheet. |
| **Change password** | Basic info now has a Change password sheet (`/auth/changePassword`). Also fixed the payload field names (`newPassword`/`confirmPassword` — the old app sent `password`/`passwordConfirmation`, which the API rejects). |
| **Avatar upload** | Basic info avatar is now editable (gallery pick → multipart `image` on updateProfile). |
| **KYC UX** | Verification URL now opens in the system browser (was a copy-paste dialog); status-aware labels (Verify / Resume / Contact support). |
| **KYC gate on posting** | Website gates Post-Trip and Post-Request behind identity verification (`identityVerificationGuard`) — the app now does the same from the shell FAB. |
| **Public user profiles** | Reviews page accepts any userId: role-split averages (as traveler / as sender), trips/requests counts, ID/phone/email verification chips. Reachable by tapping the user card on post details. |
| **Wallet ledger** | New Wallet activity page: full transaction list (`/wallet/transactions`) + withdrawal request history with statuses (`/wallet/payout-requests`). |
| **Payout fee quote** | Withdraw sheet now live-quotes fees (`/wallet/payout-requests/quote`) and shows the net amount before submitting. |
| **Wise payout fields** | Wise form now collects what the API actually stores: account holder, IBAN, SWIFT/BIC, beneficiary country, bank address. (The old form sent email + currency, which the API doesn't accept.) |
| **Stripe Connect** | Payout methods page now uses `/stripe-connect/onboard` + `/status` + `/dashboard-link`: onboarding opens in the browser, active accounts open their Express dashboard, tile label reflects the connect status. Set-default action added (PATCH). |
| **Deal agreement fields** | Agreement sheet now includes item name (required for buy-and-deliver), item link, item description, and item photos (`attachFiles[]`) — matching the website's create-deal payload. |
| **Deal validation rules** | Client-side rules from the API/website: arrival ≤ trip + 3 days; buy-and-deliver requires Stripe; security deposit requires Stripe. |
| **Payment method enum fix** | The app sent `COD`; the API only accepts `CASH_ON_DELIVERY`. Fixed (UI shows "Cash on delivery"). |
| **Product picture upload** | Post-request picture upload is real now (was a stub that only set a fake file name). Sent as `attachFile` multipart. |
| **Item description fix** | Website stores the request description in `deliveryPoints` — the app was sending `description` (which the API drops). Now sent as `deliveryPoints` and parsed back from either key. |
| **Terms/Privacy from CMS** | Terms page pulls `/lookups/getPages` (HTML → plain text), with the old hardcoded text as offline fallback. Privacy policy added to the profile menu. |
| **Plan pricing** | Increase-Visibility transporter card shows the live plan price from `/lookups/getAllPlans` instead of hardcoded USD 22.99. |
| **Report reasons** | Report-profile sheet now submits the website's enum codes (FRAUD, INAPPROPRIATE_LANGUAGE, UNPROFESSIONAL_BEHAVIOR, LOST_OR_DAMAGED_ITEMS, OTHER) with the comment as a separate field. |
| **Action-matrix alignment** | Cancel deal only while ACCEPTED (was also on OUTGOING; the website treats mid-delivery exits as disputes). Rate deal is sender-only. Mark-as-delivered is sender-only. |

## 2. App has EXTRA fields/features the website doesn't (kept, per instruction)

| Where | Extra field(s) | Notes |
|---|---|---|
| Post-a-request form | **Traveler Profit + Currency** | Collected but NOT sent — the API has no field for them (see BACKEND_GAPS §2). Kept in the UI awaiting backend support. |
| Post-trip / post-request forms | **Pickup location, Dropoff location** (visible required fields) | The website hides these and sends `'-'`; the API *requires* them. The app's visible fields are more honest — kept. |
| Post-trip form | **Notes** | Collected, not sent (no API field). |
| Search filter | **Before date** | The website has this field hidden (`d-none`); the API supports it. Kept. |
| Register | **Transporter role + business details** (legal name, address, operating countries, license/docs) | Website registration has no transporter concept; the API accepts `operatingCountries`/`businessDocuments` but drops legal name/address. Kept (client requirement per BACKEND_GAPS). |
| Notifications | **Settings sheet** (push/trip/request/marketing toggles) | No backend endpoints — stored locally. Website has no equivalent. |
| Chat | **KYC gate before opening a chat** | The website lets any logged-in user chat; the app gates chat on verified identity. Kept deliberately (stricter is safer). |
| Deals list | **Pending filter chip** | Website tabs don't include Pending; the API supports it. Kept. |

## 3. Website features intentionally NOT brought over

| Feature | Why |
|---|---|
| **Subscription checkout (Stripe plans)** | The website ships with `subscriptionFeatureEnabled=false` — routes redirect away and the sidebar hides the link. Until the flag flips, the app keeps "Apply & subscribe → coming soon" (now with live plan pricing). The `/payments/*` endpoints exist server-side when needed. |
| **Wallet top-up** | Requires an active Stripe Connect account and is a secondary web flow; server endpoints exist (`/wallet/top-up`). Can be added on request. |
| **Receiver delivery-video upload** | `uploadDeliveryVideo/{refId}` is part of the public web page the QR opens — it's the receiver's flow, on the website, not an app-user flow. |
| **Newsletter signup** | Marketing-footer widget; repo method (`addNewsletter`) is wired if a home for it is wanted. |
| **states lookups** | `/countries/getStates*` — the website doesn't actually use states in its forms either. |

## 4. Known constraints carried over from the backend

- `ApiConstants.webBaseUrl` (QR links) is set to `https://dev-dashboard.lokinter.com` — **confirm the production front-end URL before release**.
- Stripe publishable key is the TEST key from the website's dev environment — swap to the `pk_live` key (in `environment.prod.ts`) for production.
- Cities are unseeded server-side, so local posts still can't be created (BACKEND_GAPS §1.1) — unchanged by this pass.
- `PaymentController` (subscriptions) trusts a client-supplied `userId` — flagged server-side issue, unrelated to the app.
