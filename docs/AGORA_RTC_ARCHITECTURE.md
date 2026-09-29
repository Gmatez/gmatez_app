# Agora RTC architecture (Phase 5)

## Separation of concerns

| Layer | Owns |
| --- | --- |
| NestJS calling service | Call state, eligibility, hold, settlement, RTC authorization |
| Socket.IO | Signaling only (`call.*`, heartbeat) — never media |
| Agora | Microphone / camera / audio-video transport |
| Flutter | Permissions, join/leave, UI, heartbeat participation |

Billing starts only when the server transitions to **`CONNECTED`** (`connectedAt`). Ringing / accept alone does not charge.

## Providers

Backend `CALLING_PROVIDER`:

- `mock` — local/test; auto CONNECTED on accept; stub tokens
- `agora` — production; real RTC tokens via `agora-token`

Flutter `CALLING_MEDIA_PROVIDER`:

- `mock` — forbidden in staging/production
- `agora` — `AgoraCallMediaProvider` + `agora_rtc_engine` 6.6.4

Production rejects `CALLING_PROVIDER=mock`. Certificate never ships in Flutter.

## Channel + UID

- Channel: `gmatez-call-{callId}` (server-authoritative)
- Caller UID: `1`
- Callee UID: `2`

Clients must not invent channel names or UIDs.

## Token lifecycle

1. Call reaches `ACCEPTED` / `CONNECTING` / `CONNECTED`
2. Participant calls `POST /calls/:id/rtc-token`
3. Backend mints short-lived token (`AGORA_TOKEN_EXPIRY_SECONDS`, default 3600)
4. Flutter joins Agora
5. Flutter calls `POST /calls/:id/rtc-joined` → server moves to `CONNECTED` + `onConnected()` (hold + jobs)
6. Before expiry, Flutter renews via the same token endpoint + `renewToken`

Tokens are refused for ringing / terminal states (`CALL_RTC_FORBIDDEN`).

## Call state vs settlement

Unchanged from Phase 1:

- `CallStatus` — lifecycle
- `settlementStatus` — `PENDING` | `SETTLED` | `NOT_APPLICABLE`

## RTC failure

`POST /calls/:id/rtc-failed` → `FAILED` + settle/release per existing rules. UI must not show a fake active media session.

## Permissions

- Voice: microphone
- Video: microphone + camera
- Android / iOS usage strings configured; runtime via `permission_handler`
