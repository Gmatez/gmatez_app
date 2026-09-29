# Host lifecycle (Phase 3)

Authoritative rules. Flutter never overrides these.

## State machine

```
NOT_HOST
  └─ POST /hosts/applications → PENDING_REVIEW
PENDING_REVIEW
  ├─ admin ACTIVE (only if completeness.isComplete)
  └─ admin REJECTED
REJECTED
  └─ re-apply → PENDING_REVIEW
ACTIVE
  └─ admin SUSPENDED
SUSPENDED
  └─ admin ACTIVE (only if completeness.isComplete)
```

Hosts cannot set `ACTIVE`, `SUSPENDED`, or `REJECTED`.

## Completeness (server)

`HostCompletenessService` requires:

| Field | Rule |
| --- | --- |
| displayName | Profile ≥ 2 chars |
| bio | applicationBio or profile bio ≥ 8 |
| languages | ≥ 1 host language |
| avatar | `avatarUrl` http(s) URL |
| callTypes | voice and/or video enabled |
| pricing | integer cents ≥ 1 for both rates |
| agreements | current versions of HOST_GUIDELINES, TERMS_OF_SERVICE, PRIVACY_POLICY |
| verification | `NOT_REQUIRED` or `VERIFIED` |

`GET /hosts/me/completeness` and dashboard/me embed the same result.

Activation to `ACTIVE` with incomplete profile → `409 HOST_INCOMPLETE` + `missingFields`.

## Verification / KYC

`HostVerificationStatus`: `NOT_REQUIRED` | `PENDING` | `VERIFIED` | `REJECTED`

Default for new applications: `NOT_REQUIRED` (no external KYC wired).

Admin: `PATCH /admin/hosts/:id/verification`

External KYC provider: **CONFIG_REQUIRED** (`StubHostKycProvider`).

## Agreements

Persisted in `HostAgreementAcceptance` (`userId`, `agreementType`, `version`, `acceptedAt`).

Required on apply via `acceptedAgreements[]`. Version bumps require re-acceptance.

## Availability

| State | Manual? | Discoverable | Callable |
| --- | --- | --- | --- |
| OFFLINE | yes | no | no |
| ONLINE | yes (ACTIVE + complete) | yes | yes |
| PAUSED | yes | no | no |
| BUSY | call lifecycle only | no | no |

`lastActiveAt` updates on go-ONLINE and meaningful online profile edits / heartbeat.

After call ends: `BUSY` → `ONLINE` if still complete, else `OFFLINE`.

## Discovery

Server filters only:

- `Profile.isDiscoverable === true` (set only when ACTIVE + ONLINE)
- `User.status === ACTIVE`
- `HostProfile.status === ACTIVE`
- optional language / callType / onlineOnly
- block exclusions

Discovery is not authorization — call creation revalidates via `assertCallable`.

## Review notes

- `reviewNote` — host-facing (rejection / approval message)
- `internalNote` — admin-only, never returned on host/public APIs
