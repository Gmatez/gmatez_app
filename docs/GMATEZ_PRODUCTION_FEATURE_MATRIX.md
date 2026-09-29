# Gmatez production feature matrix (Phase 6 update)

Statuses follow Phase 0 vocabulary. Do not mark PRODUCTION_VERIFIED without staging/runtime evidence.

| ID | Domain | Change | Backend | App | Evidence |
| --- | --- | --- | --- | --- | --- |
| AUTH-001…007 | Auth | Phase 2 preserved | (unchanged) | (unchanged) | OTP/session suites still green |
| AUTH-006 | SMS | unchanged | CONFIG_REQUIRED | n/a | No live SMS credentials |
| HOST-001 | Host apply | Agreements + idempotent apply | INTEGRATED | INTEGRATED | `POST /hosts/applications`; onboarding |
| HOST-002 | Admin review | Completeness gate + notes | INTEGRATED | PARTIAL | e2e incomplete→409; admin UI Phase 11 |
| HOST-003 | Completeness | Server `HostCompletenessService` | INTEGRATED | CODE_WIRED | unit + e2e; dashboard card |
| HOST-004 | Verification/KYC | Persisted status + admin set | INTEGRATED | CODE_WIRED | External KYC **CONFIG_REQUIRED** |
| HOST-005 | Agreements | Versioned `HostAgreementAcceptance` | INTEGRATED | INTEGRATED | Required on apply |
| HOST-006 | Availability | ONLINE/OFFLINE/PAUSED; BUSY call-only | INTEGRATED | INTEGRATED | Dashboard; e2e PAUSED hide |
| HOST-007 | Discovery eligibility | ACTIVE+ONLINE only discoverable | INTEGRATED | CODE_WIRED | Discovery e2e + call revalidation |
| HOST-008 | Call-type / pricing | Server rates; disabled type fails | INTEGRATED | CODE_WIRED | `HOST_CALL_TYPE_DISABLED` |
| DISC-001 | isDiscoverable | Not client-overridable for hosts | INTEGRATED | CODE_WIRED | Profile patch ignores host flag |
| DISC-002 | Filters | language/callType/online server-side | INTEGRATED | CODE_WIRED | Phase 1 preserved |
| CALL-003 | Settlement | Phase 1 preserved | INTEGRATED | CODE_WIRED | |
| CALL-004 | Agora token / channel | Real mint + rtc-token/joined | INTEGRATED | INTEGRATED | e2e token IDOR; CONFIG_REQUIRED live Agora |
| CALL-005 | Flutter RTC media | agora_rtc_engine 6.6.4 + permissions | INTEGRATED | INTEGRATED | Needs device/staging for PRODUCTION_VERIFIED |
| CALL-006 | RTC reconnect / lifecycle | Media reconnect states + restoreIfNeeded | INTEGRATED | CODE_WIRED | No multi-device soak test yet |
| PAY-001 | Call create idempotency | Unique key + race e2e | INTEGRATED | CODE_WIRED | `phase6-hardening.e2e-spec` |
| PAY-002 | Settlement / refund | settle marker + admin refund | INTEGRATED | CODE_WIRED | Idempotent refund e2e |
| PAY-003 | Wallet reconcile | Admin reconcile endpoint | INTEGRATED | PARTIAL | Flutter admin audit/calls |
| PAY-004 | Stripe intents | Real SDK when key set | INTEGRATED | PARTIAL | CONFIG_REQUIRED live key |
| PAY-005 | Payout destinations | Required before request | INTEGRATED | INTEGRATED | Flutter destination + request |
| NOTIF-001 | Preferences + FCM send | Prefs + real FCM or throw | INTEGRATED | PARTIAL | FCM CONFIG_REQUIRED |
| NOTIF-002 | Push devices | register/refresh/cleanup | INTEGRATED | PARTIAL | Device API; delivery CONFIG_REQUIRED |
| SAFE-001 | Block / report | Affects discovery/chat/call | INTEGRATED | CODE_WIRED | Existing block e2e |
| SOCK-001 | Socket security | JWT/ACTIVE/room/IDOR | INTEGRATED | n/a | `socket-security.e2e-spec` |
| ADMIN-001 | Audit / refund / reconcile | APIs + Flutter tabs | INTEGRATED | INTEGRATED | |
| ADMIN-* | Admin UI | Calls/Payments/Payouts/Reports/Audit | INTEGRATED | INTEGRATED | Loading/empty/error/retry |
| INFRA / PROD | Env mocks | Phase 1 preserved | INTEGRATED | INTEGRATED | app-config.spec production mocks |
| CHAT-001 | Conversation persistence | Ordered-pair upsert + unique constraint | INTEGRATED | INTEGRATED | e2e concurrent open → one row |
| CHAT-002 | Message persistence | Idempotent send; fanout after commit | INTEGRATED | INTEGRATED | e2e identical keys → one message |
| CHAT-003 | Delivery/retry | Local sending/failed; server SENT/READ | INTEGRATED | INTEGRATED | No separate DELIVERED ack yet |
| CHAT-004 | Typing/presence | Block-aware typing; Redis TTL; peerOnline | INTEGRATED | INTEGRATED | gateway + list UI |
| CHAT-005 | Pagination/realtime | Cursor history + Flutter older-page load | INTEGRATED | INTEGRATED | e2e limit/cursor; thread scroll |
| CHAT-006 | Push hook | Offline notify + BullMQ jobId by messageId | INTEGRATED | n/a | FCM delivery **CONFIG_REQUIRED** |

Evidence (2026-09-18 Phase 6): `test/phase6-hardening.e2e-spec.ts`, `test/socket-security.e2e-spec.ts`, migration `20260918200000_phase6_hardening`, `docs/architecture/phase6-hardening.md`.

**Not claimed:** PRODUCTION_VERIFIED, live Stripe/FCM/Agora soak, external payout rail.
