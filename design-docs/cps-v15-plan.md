# CPS V15 Plan: Persistent Cookie Sessions

## Goal

Use secure cookie-backed sessions so reader-view preferences persist reliably across requests and server restarts.

Main targets:
- replace the process-local `Dancer2::Session::Simple` backend
- store the reader-view preference in a signed/encrypted session cookie
- require a stable deployment secret
- preserve the existing `reader`/`normal` behavior and homepage navigation

## Current Problem

The application used `Dancer2::Session::Simple`, which stores session data only in the Starman process. Preferences could disappear after a process restart and the backend was unsuitable for scaling beyond one worker.

The homepage link intentionally points to `/` and relies on the session preference. A session backend that loses or fails to carry the cookie can therefore unexpectedly return the user to reader mode.

## V15 Changes

### 1. Use Dancer2 Cookie Sessions
Status: implemented.

Updated `lib/CalibreServer.pm` to configure `Dancer2::Session::Cookie` with a required `CPS_SESSION_SECRET` and select the `Cookie` session engine.

The existing `reader_view` session value remains unchanged:

- `reader` selects the e-reader layout
- `normal` selects the standard layout

### 2. Require Stable Secret Configuration
Status: implemented.

Updated `docker-compose.yml` to pass `CPS_SESSION_SECRET` into the application and fail clearly when it is not supplied.

Production operators must provide a long, private, stable value. Changing the secret invalidates existing session cookies.

Example:

```sh
CPS_SESSION_SECRET='use-a-long-random-secret' docker compose up --build
```

Updated `README.md` with the runtime configuration requirement.

### 3. Update Test Session Configuration
Status: implemented.

Updated `docker-compose.test.yml` with a deterministic test-only secret.

Updated `t/web-reader.t` so cookie-session tests capture the refreshed cookie after changing from reader mode to normal mode before requesting the bare homepage URL.

This models browser behavior, where the new cookie is automatically retained.

### 4. Preserve Homepage Session Behavior
Status: implemented.

Homepage links remain plain `/` rather than embedding `view=normal` or `view=reader`.

The regression test verifies:

1. reader mode is selected
2. `?view=normal` changes the session
3. a subsequent bare `/` request uses normal mode from that session

## Implementation Order

1. Configure the Cookie session engine and required secret.
2. Pass the secret through Docker Compose.
3. Document deployment configuration.
4. Update cookie-aware reader session tests.
5. Run the full Dockerized test suite.

## Verification

### Automated Check

```sh
docker compose -f docker-compose.test.yml run --rm calibre-perl-server
```

Expected:
- all test files pass
- reader mode persists across requests
- switching to normal mode persists when following the plain homepage link
- cookie sessions initialize with the configured test secret

### Manual Smoke Test

```sh
CPS_SESSION_SECRET='use-a-long-random-secret' docker compose up --build
```

1. Open the site in reader mode.
2. Switch to normal view.
3. Click `Homepage`.
4. Confirm the standard layout remains active.
5. Restart the container with the same secret and confirm the preference remains valid.

## Out Of Scope For V15

- changing the Basic Auth model
- adding login/logout routes
- moving book metadata into session state
- supporting multiple secrets for key rotation
- changing reader layout or search behavior
