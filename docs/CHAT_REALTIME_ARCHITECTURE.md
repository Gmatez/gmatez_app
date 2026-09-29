# Chat + realtime architecture (Phase 4)

## Persistence is source of truth

Socket.IO is a fanout channel. A message is “sent” only after Postgres commit.

## Conversation model

- 1:1 only
- Participants stored as ordered pair `participantAId < participantBId` (string sort)
- `@@unique([participantAId, participantBId])` + upsert → concurrent creates share one row

## Message lifecycle

| Stage | Owner | Notes |
| --- | --- | --- |
| `sending` | Flutter local | Temporary id `local-{idempotencyKey}` |
| `SENT` | Server | Persisted; `status` in API payload |
| `READ` | Server | Derived when `readAt` set |
| `failed` | Flutter local | Retry reuses same idempotency key |

Server never accepts client `senderId` / `createdAt` / `readAt` as authoritative.

## Idempotency

`Message.idempotencyKey` is globally unique. Same sender + conversation + key returns the existing message (including under concurrent races via P2002 handling).

## HTTP

| Method | Path | Auth |
| --- | --- | --- |
| POST | `/conversations` | `{ userId }` peer — opens/upserts |
| GET | `/conversations` | cursor list + unread + peerOnline |
| GET | `/conversations/:id/messages` | cursor history (newest page first, items ascending) |
| POST | `/conversations/:id/messages` | `{ body, idempotencyKey }` |
| POST | `/conversations/:id/read` | marks peer→me messages read |

Participant ownership enforced on every conversation-scoped route (non-participants get `CONVERSATION_NOT_FOUND` / `CONVERSATION_FORBIDDEN` as 404).

## Socket `/ws`

Auth: JWT access token in `handshake.auth.token`. User must be `ACTIVE` or disconnect.

Rooms:

- `user:{userId}` — joined on connect (server-controlled)
- `conversation:{conversationId}` — via `conversation.subscribe` after participant + block check

Client events:

| Event | Direction | Notes |
| --- | --- | --- |
| `presence.ping` | C→S | Refresh Redis TTL 60s |
| `conversation.subscribe` | C→S | Join conversation room |
| `conversation.unsubscribe` | C→S | Leave room |
| `message.typing` | C→S | Rate-limited; blocked peers ignored |

Server events:

| Event | Payload |
| --- | --- |
| `message.created` | canonical message `{ id, conversationId, senderId, body, status, readAt, createdAt }` |
| `message.read` | `{ conversationId, readerId, readCount }` |
| `message.typing` | `{ conversationId, userId, typing }` |
| `presence.updated` | `{ userId, presence: ONLINE\|OFFLINE }` |

## Presence

Redis key `presence:{userId}` TTL 60s. Cleared when last socket for user disconnects. Stale keys expire.

## Blocking

Block either direction blocks: open conversation, send, typing relay, conversation.subscribe.

## Push hook (not FCM)

Offline recipient (no Redis presence) → `NotificationsService.notifyChatMessage` with BullMQ `jobId = chat-message:{messageId}`.

Push data contains ids only (no message body). Real FCM remains Phase 9 / CONFIG_REQUIRED when `PUSH_PROVIDER=fcm`.

## Flutter reconnect

On socket reconnect: re-subscribe conversation, fetch latest page, upsert by id/idempotency key, mark read.
