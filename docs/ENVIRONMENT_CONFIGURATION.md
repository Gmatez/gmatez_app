# Environment configuration

Authoritative environments: `development` | `test` | `staging` | `production`.

Never put real secrets in this document. Use placeholders only.

## Rules

| Rule | development | test | staging | production |
| --- | --- | --- | --- | --- |
| Mock providers default | yes | yes | no — explicit only | **forbidden** |
| `ALLOW_MOCK_PROVIDERS=true` | optional | optional | required if any `*_PROVIDER=mock` | **startup fails** |
| Missing provider env | defaults to mock | defaults to mock | **startup fails** | **startup fails** |
| Flutter localhost API | allowed | allowed | **forbidden** | **forbidden** |
| Flutter `MockCallMediaProvider` | allowed | allowed | **forbidden** | **forbidden** |
| `POST /payments/:id/sandbox-confirm` | allowed when payment=mock | allowed when payment=mock | only if mocks explicitly allowed | **404 / never** |

## Backend (`gmatez-app_backend`)

Validated by `loadConfig()` in `src/config/app-config.ts` at process start. Fail fast — no warn-and-continue.

### Shared required secrets

```
DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/DB
REDIS_URL=redis://HOST:6379
JWT_ACCESS_SECRET=<at-least-32-chars>
JWT_REFRESH_SECRET=<at-least-32-chars>
PAYMENT_WEBHOOK_SECRET=<at-least-16-chars>
CALLING_WEBHOOK_SECRET=<at-least-16-chars>
OTP_PEPPER=<at-least-16-chars>
CORS_ORIGINS=https://app.example.com
```

### Providers

```
OTP_PROVIDER=mock|sms
SMS_PROVIDER=msg91|twilio   # required when OTP_PROVIDER=sms
CALLING_PROVIDER=mock|agora
PAYMENT_PROVIDER=mock|stripe|razorpay
PUSH_PROVIDER=mock|fcm
```

**OTP / SMS (Phase 2 CURRENT):**

| Setting | Notes |
| --- | --- |
| `OTP_LENGTH` | default 6 |
| `OTP_TTL_SECONDS` | default 300 |
| `OTP_MAX_ATTEMPTS` | default 5 |
| `OTP_RESEND_COOLDOWN_SECONDS` | default 60 |
| `OTP_MAX_SENDS_PER_WINDOW` | per-phone send cap (default 5 / hour window) |
| `OTP_SEND_WINDOW_SECONDS` | default 3600 |
| `OTP_MAX_SENDS_PER_IP_WINDOW` | per-IP send cap (default 20) |
| `OTP_MAX_VERIFY_PER_WINDOW` | per-phone verify cap (default 10) |
| `OTP_VERIFY_WINDOW_SECONDS` | default 3600 |
| `SUPPORTED_PHONE_REGIONS` | e.g. `IN,US,GB` |
| `DEFAULT_PHONE_REGION` | e.g. `IN` |
| `JWT_ACCESS_TTL` | default `15m` |
| `JWT_REFRESH_TTL` | default `30d` |

When `OTP_PROVIDER=sms` + `SMS_PROVIDER=msg91`:
`MSG91_AUTH_KEY`, `MSG91_TEMPLATE_ID` required; optional `MSG91_SENDER_ID`.
India production also requires an approved DLT template whose OTP variable matches MSG91 template config (do not hardcode template IDs in source).

When `OTP_PROVIDER=sms` + `SMS_PROVIDER=twilio`:
`TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM_NUMBER` required.

Missing SMS credentials with `OTP_PROVIDER=sms` → **startup failure**. Never silent mock fallback.

**Other providers:** Production requires non-mock names and their secrets. There is no silent fallback to mock.

When `CALLING_PROVIDER=agora`: `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE` required.
When `PAYMENT_PROVIDER=stripe` in production: `STRIPE_SECRET_KEY` required.
When `PAYMENT_PROVIDER=razorpay` in every environment: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, and `RAZORPAY_WEBHOOK_SECRET` are required. The key secret and webhook secret stay on the server. `PLATFORM_CURRENCY` defaults to `INR`. Put values in `.env`, not in source. Webhook URL: `POST /api/v1/payments/webhooks/razorpay`. See `gmatez_backend/docs/architecture/razorpay.md`.
When `PUSH_PROVIDER=fcm` in production: `FIREBASE_SERVICE_ACCOUNT_JSON` required.

### LOCAL (development)

```
NODE_ENV=development
OTP_PROVIDER=mock
CALLING_PROVIDER=mock
PAYMENT_PROVIDER=mock
PUSH_PROVIDER=mock
MOCK_OTP=123456   # optional fixed OTP for demos
PORT=43121
```

API: `http://127.0.0.1:43121/api/v1`  
Swagger: `http://127.0.0.1:43121/api/v1/docs`  
Realtime: `http://127.0.0.1:43121/ws`

### TEST

```
NODE_ENV=test
# providers default to mock via test/setup-env.ts
```

Uses dedicated Postgres DB (`social_calling_test` by convention).

### STAGING

```
NODE_ENV=staging
# Prefer sandbox credentials with real provider names, e.g.:
OTP_PROVIDER=sms
CALLING_PROVIDER=agora
PAYMENT_PROVIDER=razorpay
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
RAZORPAY_WEBHOOK_SECRET=
PLATFORM_CURRENCY=INR
PUSH_PROVIDER=fcm
# OR explicit staging sandbox with mocks:
ALLOW_MOCK_PROVIDERS=true
OTP_PROVIDER=mock
CALLING_PROVIDER=mock
PAYMENT_PROVIDER=mock
PUSH_PROVIDER=mock
```

### PRODUCTION

```
NODE_ENV=production
OTP_PROVIDER=sms
SMS_PROVIDER=msg91
MSG91_AUTH_KEY=...
MSG91_TEMPLATE_ID=...
MSG91_SENDER_ID=...
CALLING_PROVIDER=agora
PAYMENT_PROVIDER=razorpay
RAZORPAY_KEY_ID=...
RAZORPAY_KEY_SECRET=...
RAZORPAY_WEBHOOK_SECRET=...
PLATFORM_CURRENCY=INR
PUSH_PROVIDER=fcm
AGORA_APP_ID=...
AGORA_APP_CERTIFICATE=...
FIREBASE_SERVICE_ACCOUNT_JSON=...
```

Do **not** set `ALLOW_MOCK_PROVIDERS=true`. Startup rejects it.

Render free demo (`render.yaml`) uses `NODE_ENV=development` intentionally — it is **not** a production deployment.

## Flutter (`gmatez-app`)

Dart-defines:

| Define | Purpose |
| --- | --- |
| `ENVIRONMENT` | `development` \| `test` \| `staging` \| `production` (default `development`) |
| `API_BASE_URL` | Required for staging/production. Local default `http://127.0.0.1:43121/api/v1` |
| `WS_BASE_URL` | Optional Socket.IO origin override |
| `CALLING_MEDIA_PROVIDER` | `mock` \| `agora`. Local defaults to mock; staging/production default agora and reject mock |

### LOCAL

```
flutter run
# or physical Android with adb reverse:
adb reverse tcp:43121 tcp:43121

# Android emulator alternative:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:43121/api/v1
```

### STAGING / PRODUCTION

```
flutter build apk \
  --dart-define=ENVIRONMENT=production \
  --dart-define=API_BASE_URL=https://api.example.com/api/v1 \
  --dart-define=CALLING_MEDIA_PROVIDER=agora
```

Missing `API_BASE_URL` or loopback URL → startup `StateError`.  
`CALLING_MEDIA_PROVIDER=mock` → startup `StateError`.

## Payment authority

1. Client creates `POST /payments/intents`.
2. Provider confirms payment (webhook / verified event).
3. Server credits wallet via ledger.

Flutter UI success and `sandbox-confirm` are **never** authoritative in production. `sandbox-confirm` is TEST/DEV only and returns 404 in production.
