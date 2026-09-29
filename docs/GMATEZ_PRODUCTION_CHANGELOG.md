# Gmatez production changelog

## 2026-09-18 — Phase 6: Production hardening

### Backend
- Call create idempotency (`Call.idempotencyKey` unique) + concurrent create e2e
- `settlementAppliedAt` + idempotent settle/refund (`POST /admin/calls/:id/refund`)
- Wallet reconcile (`GET /admin/users/:id/wallet/reconcile`)
- Configurable `CREATOR_SHARE_BPS`; call history earnings fields + filters
- Payout destinations (`POST/GET /payouts/destinations`) required before payout
- Report `referenceType`/`referenceId`; notification preferences
- Admin audit logs API; Stripe/FCM providers throw without credentials (no fake success)
- IDOR + accept/cancel race + payout + refund concurrency e2e (`test/phase6-hardening.e2e-spec.ts`)
- Socket security e2e (`test/socket-security.e2e-spec.ts`): unauth/invalid/expired JWT, suspended, room IDOR
- Docs: `docs/architecture/phase6-hardening.md`
- Migration applied to `social_calling` + `social_calling_test` via `scripts/ensure-test-db.js`

### Flutter
- Call history settlement/earnings display; wallet held balance
- Notification tap deep links; admin Calls/Payments/Audit surfaces
- Payout destination save + request gated on destination

### CONFIG_REQUIRED
- Live Stripe (`STRIPE_SECRET_KEY`)
- Live FCM (`FIREBASE_SERVICE_ACCOUNT_JSON`)
- Device/staging soak for payments + push + Agora (Phase 5)

### BUSINESS_RULE_REQUIRED
- Exact refund policy beyond full settled-call reverse
- External payout rail after destination capture
- Creator share % beyond default `CREATOR_SHARE_BPS=8000`

---

## 2026-09-18 — Phase 5: Real Agora voice/video RTC

### Feature IDs
CALL-004, CALL-005, CALL-006

### Backend
- Real Agora RTC token minting (`agora-token`) with `AGORA_TOKEN_EXPIRY_SECONDS`
- Channel `gmatez-call-{callId}`; UIDs caller=1 / callee=2
- `POST /calls/:id/rtc-token|rtc-joined|rtc-failed`
- Agora accept → CONNECTING; first `rtc-joined` → CONNECTED + billing hold
- Mock path unchanged (auto CONNECTED)

### Flutter
- `agora_rtc_engine` 6.6.4 + `permission_handler`
- Real `AgoraCallMediaProvider` (join/leave/mute/camera/speaker/renew)
- Android/iOS mic+camera permissions; video UI surfaces
- Token renewal, double-join guard, restore active call on resume

### CONFIG_REQUIRED
- Live `AGORA_APP_ID` / `AGORA_APP_CERTIFICATE` on staging/production
- Device verification of real media path

### Not done
- Phase 6+ (payments polish, FCM Phase 9, etc.)
- No claim of PRODUCTION_VERIFIED without staging devices

---

## 2026-09-18 — Phase 4: Chat + realtime + presence + push hooks

### Feature IDs
CHAT-001…CHAT-006

### Backend changes
- Chat send rate limits; stricter message error codes
- Message payload includes `status` SENT|READ
- Typing/subscribe enforce participant + block
- Conversation rooms via `conversation.subscribe`
- Offline recipient → `notifyChatMessage` with idempotent BullMQ `jobId`
- Gateway rejects non-ACTIVE socket JWT subjects
- Conversation list exposes `peerOnline`

### Flutter changes
- Chat history pagination (load older on scroll)
- Reconnect reconcile + conversation subscribe
- Sent/Read/Failed UI; idempotent upsert
- Conversation list online indicator

### Database
None (existing Conversation/Message uniqueness sufficient)

### Socket events
Documented in `docs/CHAT_REALTIME_ARCHITECTURE.md` and `backend-contract.md`

### Tests
- `test/chat-realtime.e2e-spec.ts` (concurrency, idempotency, IDOR, block, pagination, read)
- Flutter `chat_models_test.dart` expanded

### CONFIG_REQUIRED
- FCM / real push delivery (Phase 9)
- Phase 2 SMS, Phase 3 KYC unchanged

### Remaining gaps
- No multi-device DELIVERED ack beyond socket presence
- No media message types (text-only by design)
- Agora/RTC Phase 5 not started

---

## 2026-09-18 — Phase 3: Host lifecycle + completeness + discovery readiness

### Feature IDs
HOST-001…HOST-008, DISC-001/002, HOST KYC CONFIG_REQUIRED

### Backend changes
- `HostCompletenessService` + `GET /hosts/me/completeness`
- Versioned `HostAgreementAcceptance`; required on apply
- `HostVerificationStatus` + admin verification endpoint
- ACTIVE gate refuses incomplete hosts (`HOST_INCOMPLETE`)
- Availability: only ONLINE is discoverable; BUSY call-owned; PAUSED supported
- Hosts cannot self-set `Profile.isDiscoverable`
- Stable host error codes; call eligibility revalidation codes refined
- Admin host detail endpoint; host-facing vs internal notes

### Flutter changes
- Onboarding posts `acceptedAgreements`
- Dashboard shows completeness + ONLINE/PAUSED/OFFLINE (no BUSY)
- ErrorMapper host codes; `HostSnapshot.verificationStatus`
- App resume reconciles `/users/me` (`SessionLifecycle`)
- Host `SUSPENDED` / pending routing + pending screen states
- Onboarding draft persisted locally for resume after process death

### Database
- Migration `20260918180000_host_completeness_agreements`
  - `HostVerificationStatus`, `HostProfile.verificationStatus`, `internalNote`
  - `HostAgreementAcceptance`

### Tests
- `test/host-lifecycle.e2e-spec.ts`, completeness unit tests
- Updated discovery/activateHost helpers for agreements + avatar
- Flutter `host_onboarding_test.dart`

### CONFIG_REQUIRED
- External KYC/identity provider (stub only)
- Phase 2 SMS credentials (unchanged)

### Remaining gaps
- Admin Flutter UI for host review (Phase 11)
- External KYC provider integration
- Full device E2E (Phase 12)

---

## 2026-09-18 — Phase 2: Auth hardening + SMS adapters + abuse protection

### Feature IDs
AUTH-001, AUTH-002, AUTH-003, AUTH-004, AUTH-005, AUTH-006 (CONFIG_REQUIRED), AUTH-007

### Backend changes
- OTP delivery abstraction: `MockOtpDeliveryProvider` | `Msg91OtpDeliveryProvider` | `TwilioOtpDeliveryProvider`
- `AuthService` owns generation, HMAC hashing, TTL, attempts, resend cooldown, session issue; providers only send SMS
- Phone normalization via `SUPPORTED_PHONE_REGIONS` / `DEFAULT_PHONE_REGION` (E.164 internally)
- Redis namespaced keys: `gmatez:otp:*`, `gmatez:ratelimit:otp:*`
- Per-phone and per-IP send/verify rate limits; generic OTP request responses (enumeration hardening)
- Stable auth/OTP error codes + optional `details.retryAfterSeconds`
- Refresh: atomic claim, reuse detection after 15s grace (concurrent race safe), logout family revoke
- JWT guard rejects SUSPENDED/DELETED with `ACCOUNT_*` codes
- Production still rejects `OTP_PROVIDER=mock`; `OTP_PROVIDER=sms` requires SMS credentials at startup

### Flutter changes
- OTP UX: cooldown/resend, paste, loading, mapped errors, scrollable layout
- Auth interceptor: no Bearer on OTP paths; suspended/reuse clears session; refresh serialization
- `AuthStatus.suspended` + `/account/suspended` gate
- ErrorMapper maps OTP/session/account codes and `retryAfterSeconds`

### Database changes
None in Phase 2 (phone uniqueness already present from prior migration)

### API changes
- Phone OTP request may return `resendAvailableInSeconds`
- Error envelope `details.retryAfterSeconds` for rate/cooldown
- Auth error codes documented in `backend-contract.md`

### Security changes
- No plaintext OTP storage; masked phone in logs; no OTP/tokens/SMS secrets in logs
- Concurrent refresh does not wipe winner session within grace window
- Suspended users cannot use protected APIs

### Tests executed
- Backend: `npm run build`, `npm test` (35), `npm run test:e2e` (20)
- Flutter: `flutter analyze`, `flutter test` (49)

### Configuration still required for live SMS
- MSG91: `MSG91_AUTH_KEY`, `MSG91_TEMPLATE_ID`, optional `MSG91_SENDER_ID` + India DLT template approval
- **or** Twilio: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM_NUMBER`
- Production: `OTP_PROVIDER=sms`, `SMS_PROVIDER=msg91|twilio`

### Remaining Phase 2 limitations
- Live SMS delivery not end-to-end verified (CONFIG_REQUIRED)
- Email/password auth APIs still present (compat); product path is phone OTP
- Observability counters are log-event hooks only (metrics phase later)
- Flutter device integration / full app E2E still Phase 12

### Phase 3 Flutter follow-up (same day)
- App resume reconciles `/users/me` via `SessionLifecycle`
- Host `SUSPENDED` / pending routing + pending screen states
- Onboarding draft persisted locally for resume after process death

---

## 2026-09-18 — Phase 1: Contracts + environment + mock safety

### Feature IDs
AUTH-001 (partial), DISC-001, CALL-003, PAY sandbox safety, HOST-001 contract, PROD env validation, Flutter media/API safety

### Backend changes
- `loadConfig` environments: development | test | staging | production
- `OTP_PROVIDER`; providers no longer silently default to mock outside local/test
- Production rejects all mock providers; `ALLOW_MOCK_PROVIDERS` cannot bypass production
- Discovery requires `Profile.isDiscoverable === true`
- Call responses include derived `settlementStatus`
- `sandbox-confirm` impossible in production
- Demo OTP only when `OTP_PROVIDER=mock` and mocks allowed
- E2E helpers: host apply → admin ACTIVE → ONLINE
- Config + settlement contract unit tests; refreshed e2e

### Flutter changes
- Local API default `http://127.0.0.1:43121/api/v1` (no silent Render default)
- Staging/production require `API_BASE_URL`; reject loopback
- `CALLING_MEDIA_PROVIDER`; production/staging select Agora stub, refuse mock
- Auth interceptor excludes phone OTP paths from Bearer attachment
- Wallet sandbox-confirm only when `allowsMockPayments`
- `CallSettlementStatus` on call models
- Admin ApiPaths aligned with backend (UI still Phase 11)

### Database changes
None (settlement status is derived)

### API / Socket changes
- Call DTO adds `settlementStatus`
- Host apply contract documented as flat rate fields

### Tests added
- `src/config/app-config.spec.ts`
- `src/modules/calling/call-settlement.contract.spec.ts`
- Updated `test/app.e2e-spec.ts`, `test/discovery-profile.e2e-spec.ts`
- Flutter `app_config_test.dart`, `auth_interceptor_test.dart`

### Known limitations
- Real SMS adapters landed in Phase 2 (CONFIG_REQUIRED until credentials tested)
- Agora SDK / Stripe SDK / FCM still PLANNED
- Agora Flutter provider throws until Phase 5
- Admin audit-log GET still missing
