# Gmatez Flutter app

Production client for the Gmatez social discovery and real-time calling platform.

The backend at `../gmatez-app_backend` is authoritative for identity, host lifecycle, call signaling, billing, wallets, earnings, and payouts. This app owns UI, navigation, RTC media, and user interaction. Flutter never credits a wallet, settles a call, or changes host status locally.

## Architecture

```
Presentation (screens, Riverpod notifiers)
  -> Repositories
    -> Dio API client / Socket.IO
```

Feature-first layout lives under `lib/features`. Shared networking, storage, errors, logging, and design tokens live under `lib/core` and `lib/app`.

Host is **not** a Flutter-assigned role. `UserRole` is `USER` or `ADMIN`. Host is a backend `HostProfile` lifecycle (`NOT_HOST` → `PENDING_REVIEW` → `ACTIVE` / `REJECTED` / `SUSPENDED`).

## Run

Backend default: `http://127.0.0.1:43121/api/v1`.

On Android (emulator or a USB/wireless phone) forward the API port first. `10.0.2.2` only works inside the emulator, not on a physical device.

```bash
adb reverse tcp:43121 tcp:43121
flutter pub get
flutter run
```

Emulator without reverse:

```bash
flutter run \
  --dart-define=ENVIRONMENT=development \
  --dart-define=API_BASE_URL=http://10.0.2.2:43121/api/v1 \
  --dart-define=WS_BASE_URL=http://10.0.2.2:43121/ws
```

Backend (from `../gmatez-app_backend`):

```bash
docker compose up -d redis
npx prisma migrate deploy
npx prisma db seed
npm run start:dev
```

Seed password for all local users: `ChangeMe123!`

- `alice@example.com` — caller (not a host)
- `bob@example.com` — ACTIVE host, ONLINE
- `carol@example.com` — ACTIVE host, OFFLINE
- `dave@example.com` — ACTIVE host, BUSY
- `eve@example.com` — PENDING_REVIEW host
- `hidden@example.com` — SUSPENDED host
- `admin@example.com` — ADMIN

## Auth

- `POST /api/v1/auth/otp/request`
- `POST /api/v1/auth/otp/verify`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`

OTP verify only succeeds for an **existing active user**. New users must register first. Access and refresh tokens are stored in secure storage, never in SharedPreferences, and never logged.

## Product surfaces

Callers: Home, Discover, Calls, Chat, Profile, Wallet.

Hosts: Dashboard, Earnings, Calls, Chat, Profile, call settings, payouts.

Admins: `/admin` console (hosts, users, payouts, reports) plus Swagger at `/api/v1/docs`.

Calling UI starts a real backend call. Wallet purchase uses payment intents. With `PAYMENT_PROVIDER=mock` (non-production only) the app confirms through the sandbox endpoint. With `PAYMENT_PROVIDER=razorpay` the app opens Razorpay Checkout using the public key id from the intent, then `POST /payments/:id/verify`. The key secret never ships in the app. A checkout callback is not a wallet credit until the server reports `SUCCEEDED`. Agora remote A/V requires `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE`.

See `docs/backend-contract.md`.

## Quality

```bash
dart format .
flutter analyze
flutter test
```
