# Backend contract (from gmatez-app_backend)

**Status labels:** CURRENT = implemented now. PLANNED = later phase — do not treat as shipped.

Base URL (local): `http://127.0.0.1:43121/api/v1`  
Swagger: `http://127.0.0.1:43121/api/v1/docs`  
Realtime: Socket.IO namespace `/ws`, JWT in `handshake.auth.token`

Environment matrix: see `docs/ENVIRONMENT_CONFIGURATION.md`.

## Error envelope

```json
{
  "error": {
    "code": "UNAUTHENTICATED",
    "message": "Authentication required",
    "requestId": "uuid"
  }
}
```

| HTTP | Typical codes |
| --- | --- |
| 400 | `VALIDATION_FAILED`, `OTP_INVALID`, `OTP_EXPIRED`, `OTP_TOO_MANY_ATTEMPTS`, `OTP_RESEND_COOLDOWN` |
| 401 | `UNAUTHENTICATED`, `INVALID_CREDENTIALS`, `AUTH_INVALID_SESSION`, `AUTH_REFRESH_REUSED`, `AUTH_SESSION_REVOKED`, `REFRESH_TOKEN_INVALID` |
| 403 | `FORBIDDEN`, `ACCOUNT_SUSPENDED`, `ACCOUNT_DELETED`, `USER_SUSPENDED`, `USER_BLOCKED` |
| 404 | `NOT_FOUND` |
| 409 | `CONFLICT`, `CALL_ALREADY_ACTIVE` |
| 422 | validation (if used) |
| 429 | `OTP_RATE_LIMITED`, `RATE_LIMITED` |
| 502 / 503 | `OTP_DELIVERY_FAILED` |
| 500 | `INTERNAL` |

Rate / cooldown responses may include:

```json
{
  "error": {
    "code": "OTP_RATE_LIMITED",
    "message": "Please try again later.",
    "requestId": "uuid",
    "details": { "retryAfterSeconds": 60 }
  }
}
```

Flutter must map `error.code` (and `details.retryAfterSeconds`) — never parse provider strings.

Domain codes (CURRENT): `WALLET_INSUFFICIENT_FUNDS`, `CALL_INVALID_TRANSITION`, `CALL_NOT_PARTICIPANT`, `CALL_ALREADY_ACTIVE`, `USER_BUSY`, `HOST_OFFLINE`, `HOST_BUSY`, `HOST_NOT_APPROVED`, `PAYOUT_NOT_ELIGIBLE`, `PAYMENT_WEBHOOK_INVALID`.

Flutter maps these via `ErrorMapper` to user-safe strings (never raw stack traces).

Pagination: `limit` (1–50, default 20) and `cursor`. Response: `{ "items": [], "nextCursor": null }`.

## Auth (CURRENT)

**Authoritative product flow (Flutter):** phone OTP request → verify → session (login or register).

| Method | Path | Auth | Request | Response |
| --- | --- | --- | --- | --- |
| POST | `/auth/phone/otp/request` | public | `{ phone }` | `{ expiresInSeconds, resendAvailableInSeconds? }` — always generic success shape when accepted |
| POST | `/auth/phone/otp/verify` | public | `{ phone, otp }` | session; creates user+profile+wallet if new (phone unique) |
| POST | `/auth/refresh` | public | `{ refreshToken }` | rotated session (family rotation; reuse detection) |
| POST | `/auth/logout` | public | `{ refreshToken }` | 204 — revokes refresh family |
| POST | `/auth/register` | public | `{ email, password>=10, displayName>=2 }` | session — **legacy compat**, not Flutter product path |
| POST | `/auth/login` | public | `{ email, password }` | session — **legacy compat** |
| POST | `/auth/otp/request` | public | `{ email }` | `{ expiresInSeconds, otp? }` — **legacy email OTP**; otp field only when mock expose allowed |
| POST | `/auth/otp/verify` | public | `{ email, otp }` | session; user must exist — **legacy** |

Session payload: `{ accessToken, refreshToken, user: { id, role, status, ... } }`.

### OTP security (CURRENT)

- Cryptographic OTP generation; length/TTL/attempts/cooldown from env
- HMAC-hashed storage in Redis (`OTP_PEPPER`); never plaintext OTP in Redis/logs
- Previous OTP invalidated on resend; one-time use; max verify attempts
- Per-phone + per-IP Redis rate limits
- Phone stored/looked up as E.164 using `SUPPORTED_PHONE_REGIONS` / `DEFAULT_PHONE_REGION`

### SMS delivery (CURRENT + CONFIG_REQUIRED)

| `OTP_PROVIDER` | Behavior |
| --- | --- |
| `mock` | Allowed in development/test (or staging with `ALLOW_MOCK_PROVIDERS=true`). **Startup fails in production.** |
| `sms` | Requires `SMS_PROVIDER=msg91\|twilio` + provider credentials. Missing credentials → **startup failure** (no silent mock fallback). |

Adapters: MSG91 (India DLT template) and Twilio Programmable Messaging. Live delivery requires external accounts — status **CONFIG_REQUIRED** until credentials are configured and tested.

Public auth paths must not send stale Bearer tokens from the Flutter interceptor.

### Account status (CURRENT)

| `User.status` | Auth / API |
| --- | --- |
| `ACTIVE` | Normal |
| `SUSPENDED` | Login/OTP session issuance blocked; protected APIs → `403 ACCOUNT_SUSPENDED` |
| `DELETED` | `403 ACCOUNT_DELETED` |

Flutter must clear local session and route to `/account/suspended` on `ACCOUNT_SUSPENDED` (server authoritative).

## Roles and host status (CURRENT)

- `User.role`: `USER` \| `ADMIN`
- Host is **not** a JWT role. Lifecycle is `HostProfile.status`: `PENDING_REVIEW` → `ACTIVE` \| `REJECTED`; `ACTIVE` ↔ `SUSPENDED`
- Flutter/client cannot self-activate a host. Admin `PATCH /admin/hosts/:userId/status` is authoritative.
- Availability: `OFFLINE` \| `ONLINE` \| `PAUSED` \| `BUSY` (BUSY is call-lifecycle only)

## Discovery (CURRENT)

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/discovery/feed` | Cursor page |
| GET | `/discovery/search` | `q` min 2 chars |

Server filters (all required):

- Viewer excluded; blocks either way excluded
- `User.status === ACTIVE`
- `HostProfile.status === ACTIVE`
- `Profile.isDiscoverable === true`
- Optional: `online=true` → host `availability === ONLINE` and callable
- Optional: `callType`, `language` (matches `HostProfile.languages`)

## Profiles (CURRENT)

| Method | Path | Notes |
| --- | --- | --- |
| GET/PATCH | `/profiles/me` | Own profile only |
| GET | `/users/:id` | Public card; blocked/deleted/undiscoverable → NOT_FOUND (self view allowed) |

Avatar is URL field today (upload storage PLANNED).

## Chat (CURRENT)

See `docs/CHAT_REALTIME_ARCHITECTURE.md`.

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/conversations` | `{ userId }` peer; upsert ordered pair; block-aware |
| GET | `/conversations` | cursor; includes `unreadCount`, `peerOnline` |
| GET | `/conversations/:id/messages` | cursor history; participant-only |
| POST | `/conversations/:id/messages` | `{ body<=2000, idempotencyKey>=8 }`; returns `{ id, status: SENT\|READ, ... }` |
| POST | `/conversations/:id/read` | marks inbound unread; emits `message.read` |

Errors: `MESSAGE_INVALID`, `MESSAGE_TOO_LONG`, `MESSAGE_RATE_LIMITED`, `MESSAGE_BLOCKED`, `CONVERSATION_NOT_FOUND`, `CONVERSATION_FORBIDDEN`.

### Socket `/ws` (CURRENT)

Auth: `handshake.auth.token` = access JWT; user must be ACTIVE.

| Event | Dir | Payload |
| --- | --- | --- |
| `presence.ping` | C→S | refresh presence TTL |
| `conversation.subscribe` | C→S | `{ conversationId }` — join `conversation:{id}` if participant and not blocked |
| `conversation.unsubscribe` | C→S | `{ conversationId }` |
| `message.typing` | C→S | `{ conversationId, typing }` — rate limited |
| `message.created` | S→C | canonical message |
| `message.read` | S→C | `{ conversationId, readerId, readCount }` |
| `message.typing` | S→C | `{ conversationId, userId, typing }` |
| `presence.updated` | S→C | `{ userId, presence }` |

Offline recipients get in-app notification + push job hook (`CHAT_MESSAGE`, ids only). FCM delivery remains CONFIG_REQUIRED / Phase 9.

## Call state vs settlement (CURRENT — authoritative)

**CallStatus** (Prisma / API `status`):

`INITIATED` → `RINGING` → `ACCEPTED` → `CONNECTING` → `CONNECTED` → `ENDED`

Terminal without billable connect: `REJECTED` \| `CANCELLED` \| `TIMEOUT` \| `FAILED`

**SettlementStatus** (derived API field `settlementStatus` — not a DB enum):

| Value | Meaning |
| --- | --- |
| `PENDING` | Call still in progress |
| `SETTLED` | `ENDED` after a CONNECTED session; settlement applied (including $0 duration) |
| `NOT_APPLICABLE` | Never CONNECTED (reject/cancel/timeout/fail) or ENDED without connect |

**CRITICAL:** `ENDED` ≠ `SETTLED`. Clients must read `settlementStatus` / ledger, not assume money moved from status alone.

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/calls` | `{ calleeId, callType?: VOICE\|VIDEO, idempotencyKey? }` |
| GET | `/calls` | history |
| GET | `/calls/:id` | participant |
| POST | `/calls/:id/accept\|reject\|cancel\|end\|heartbeat` | |
| POST | `/calls/:id/rtc-token` | participant + ACCEPTED/CONNECTING/CONNECTED → `{ appId, channelName, uid, token, tokenExpiresAt }` |
| POST | `/calls/:id/rtc-joined` | Agora join ack → CONNECTED + billing hold |
| POST | `/calls/:id/rtc-failed` | `{ reason? }` → FAILED |

Rates snapshotted server-side from host profile. Client must never send authoritative charge amounts.

See `docs/AGORA_RTC_ARCHITECTURE.md`.

**CALLING_PROVIDER:** `mock` auto-advances to CONNECTED after accept (local). `agora` mints real RTC tokens; Flutter joins then calls `rtc-joined`. Production forbids mock. Certificate never leaves the backend.

## Wallet / payments (CURRENT)

Amounts are **integer minor units** (paise when `currency` is INR, cents when USD). Flutter never credits locally.

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/wallet` | balances |
| GET | `/wallet/ledger` | cursor |
| GET | `/wallet/earnings` | host totals |
| POST | `/payments/intents` | Razorpay: `{ rechargePlanId, idempotencyKey }`. Mock may still send `amountCents`. |
| POST | `/payments/:id/verify` | Razorpay checkout signature. Credits only after server verification. |
| POST | `/payments/:id/abandon` | Checkout dismissed. Recovers a capture if Razorpay already paid the order. |
| GET | `/payments/:id` | own only. Razorpay response includes public `checkout.keyId`, never the key secret. |
| POST | `/payments/webhooks/razorpay` | Raw-body `X-Razorpay-Signature`. |
| POST | `/payments/:id/sandbox-confirm` | **TEST/DEV ONLY** when `PAYMENT_PROVIDER=mock` and mocks allowed. Production → 404. |

Authority: verified Razorpay payment or mock webhook → wallet credit. Flutter success UI is not proof of payment.

**PAYMENT_PROVIDER:** `mock` \| `stripe` \| `razorpay`. Razorpay requires `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`. Host bank payouts are not sent; RazorpayX is CONFIG_REQUIRED.

## Hosts (CURRENT)

See also `docs/HOST_LIFECYCLE.md`.

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/hosts/me` | `{ hostStatus, host, completeness }` — `hostStatus` may be `NOT_HOST` |
| GET | `/hosts/me/completeness` | `{ isComplete, percentage, missingFields, verificationStatus, requiredAgreements }` |
| GET | `/hosts/me/dashboard` | host + completeness + stats |
| POST | `/hosts/applications` | apply / re-apply after REJECTED |
| PATCH | `/hosts/me` | rates/langs/call types (not status) |
| POST | `/hosts/me/availability` | `ONLINE` \| `OFFLINE` \| `PAUSED` only — never `BUSY` |

### Host apply payload (authoritative)

```json
{
  "applicationBio": "string min 8",
  "languages": ["en"],
  "interests": ["support"],
  "voiceEnabled": true,
  "videoEnabled": true,
  "voiceRatePerMinuteCents": 150,
  "videoRatePerMinuteCents": 250,
  "acceptedAgreements": [
    { "agreementType": "HOST_GUIDELINES", "version": "1.0" },
    { "agreementType": "TERMS_OF_SERVICE", "version": "1.0" },
    { "agreementType": "PRIVACY_POLICY", "version": "1.0" }
  ]
}
```

There is **no** nested `{ rates: ... }` object. Flat rate fields are CURRENT.

### Host errors (CURRENT)

| Code | When |
| --- | --- |
| `HOST_INCOMPLETE` | Admin activate or host go-ONLINE while completeness fails (`details.missingFields`) |
| `HOST_APPLICATION_EXISTS` | Duplicate pending/active application |
| `HOST_APPLICATION_INVALID` | Invalid apply payload |
| `HOST_AGREEMENT_REQUIRED` | Missing/wrong agreement versions |
| `HOST_NOT_ACTIVE` | Host not ACTIVE |
| `HOST_UNAVAILABLE` | Not ONLINE |
| `HOST_CALL_TYPE_DISABLED` | Voice/video disabled |
| `HOST_BUSY` | On a call |
| `HOST_SUSPENDED` | Suspended host action |

`BUSY` is call-lifecycle only. Discoverable only when `ACTIVE` + `ONLINE` (server sets `Profile.isDiscoverable`).

## Payouts (CURRENT)

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/payouts` | `{ amountCents>=500, idempotencyKey }` |
| GET | `/payouts` | |

No bank/UPI destination model yet (PLANNED Phase 8). Admin completes/rejects manually.

## Notifications / devices (CURRENT contract; FCM send PLANNED Phase 9)

| Method | Path | Auth | Body |
| --- | --- | --- | --- |
| GET | `/notifications` | Bearer | inbox |
| POST | `/notifications/read-all` | Bearer | |
| POST | `/notifications/:id/read` | Bearer | |
| POST | `/notifications/devices` | Bearer | `{ token: string>=8, platform: "ios"\|"android" }` |
| DELETE | `/notifications/devices/:token` | Bearer | 204 |

Ownership: token upsert binds to authenticated `userId`. Delete only removes tokens owned by the caller. Duplicate token moves ownership to the registering user. Logout should DELETE device tokens (Flutter wiring PLANNED Phase 9). Unauthorized users cannot register for other user IDs (no userId in body).

In-app notifications CURRENT. Push delivery via FCM is STUB/PLANNED.

## Admin (CURRENT APIs; Flutter UI partial — Phase 11)

All require `role=ADMIN`.

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/admin/overview` | |
| GET | `/admin/users` | `status?`, `q?` |
| GET | `/admin/users/:id` | detail |
| PATCH | `/admin/users/:id/status` | |
| GET | `/admin/hosts` | `status?` — includes completeness-related fields |
| GET | `/admin/hosts/:id` | detail + completeness + agreements (admin) |
| PATCH | `/admin/hosts/:id/status` | `:id` = host **userId**; ACTIVE gated by completeness |
| PATCH | `/admin/hosts/:id/verification` | `{ verificationStatus, internalNote? }` |
| GET | `/admin/calls` | |
| GET | `/admin/calls/:id` | |
| GET | `/admin/payments` | |
| GET/PATCH | `/admin/payouts` | |
| GET/PATCH | `/admin/reports` | |
| POST | `/admin/wallet/adjustments` | `{ userId, amountCents signed, reason }` |
| GET | `/admin/banners` | list all promo banners |
| POST | `/admin/banners` | create (`title` required) |
| PATCH | `/admin/banners/:id` | update / toggle |
| DELETE | `/admin/banners/:id` | hard delete |

## Promo banners (CURRENT)

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | `/banners` | Bearer | Active banners for caller (audience ALL+USER or ALL+HOST; schedule window) |

Deep links are in-app paths (`/wallet`, `/discover`, `/host/apply`, …).

Audit logs are **written** on sensitive actions. `GET /admin/audit-logs` is **PLANNED** (Phase 11).

## Realtime (CURRENT)

Client emit: `presence.ping`, `call.heartbeat` `{ callId }`, `message.typing` `{ conversationId, typing }`.

Server emit (no tokens/secrets): `call.*`, `presence.updated`, `wallet.updated`, `notification.received`, `message.*`, `host.availability.updated`.

## Safety (CURRENT)

Blocks and reports as listed previously. Mute preferences PLANNED.
