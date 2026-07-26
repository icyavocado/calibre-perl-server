# CPS V11 Plan: Basic Auth Only, No Nginx

## Goal
Simplify runtime and auth by:

- removing form login and session-based user auth
- requiring HTTP Basic auth for all app routes when `users.sqlite` exists
- removing nginx from Docker Compose
- exposing Starman directly on `127.0.0.1:5000`

## Current Problem
Before v11, the stack had two layers of complexity that were no longer needed:

- dual auth flows (form/session for web + Basic for OPDS)
- nginx proxy/cache/auth-state routing in front of a single-worker app

This created extra routes and behavior to maintain (`/login`, `/logout`, nginx auth/cache maps) without clear benefit for this personal read-only server.

## V11 Changes

### 1. Remove Form Login Flow
Status: implemented.

Removed app-level form/session login endpoints and related helpers:

- removed `GET /login`
- removed `POST /login`
- removed `POST /logout`
- removed `_safe_return_url`
- removed `_is_public_path`

Why:

- one auth mechanism is easier to reason about
- no open-redirect surface from login return URLs
- fewer route-specific auth exceptions

### 2. Enforce Basic Auth Globally
Status: implemented.

When auth is enabled (`users.sqlite` exists), the `before` hook now enforces `_require_basic_auth()` for all request paths.

Behavior:

- no credentials -> `401` with `WWW-Authenticate: Basic`
- valid Basic credentials -> request proceeds
- auth disabled (no `users.sqlite`) -> anonymous access still allowed

Why:

- same auth behavior across web and OPDS routes
- avoids session login state divergence from Basic-auth state

### 3. Keep Reader View Preference Session
Status: implemented.

Reader mode preference (`?view=reader` / `?view=normal`) remains session-backed for UI mode persistence.

Why:

- this session value is presentation-only, not authentication
- keeps existing reader-mode UX without extra URL noise on every click

### 4. Remove Login-Specific Frontend Assumptions
Status: implemented.

Updated frontend cacheability logic in `public/js/main.js` by removing `/login` and `/logout` exceptions, since those routes no longer exist.

Why:

- avoids stale special-casing of removed routes
- keeps client logic aligned with server route table

### 5. Update Test Helpers and Auth Tests
Status: implemented.

Test updates:

- removed `post_login` helper from `t/lib/TestApp.pm`
- migrated auth-on tests to use Basic `Authorization` headers
- updated anonymous auth-on expectations to `401` for protected routes
- asserted `/login` and `/logout` now return `404`
- retained download header assertions and OPDS coverage under Basic auth

Why:

- test behavior now matches runtime reality
- catches regressions if login/session auth accidentally returns

### 6. Remove Nginx From Compose Runtime
Status: implemented.

Docker Compose now runs only the app service:

- removed `nginx` service from `docker-compose.yml`
- published app directly as `127.0.0.1:5000:5000`
- removed `nginx/nginx.conf`

Why:

- fewer moving parts in local deployment
- no proxy/auth/cache map maintenance burden
- direct path from client to app for debugging and ops

### 7. Update Runtime Documentation
Status: implemented.

`README.md` updated to reflect:

- direct app entrypoint at `http://localhost:5000`
- auth wording changed to HTTP Basic
- runtime section now describes direct Starman serving

Why:

- docs now match compose behavior and route/auth reality

## Implementation Order
1. Remove form login/logout routes and auth helper code.
2. Make `before` hook enforce Basic auth globally when enabled.
3. Update frontend special-case route logic.
4. Migrate tests to Basic-auth-only expectations.
5. Remove nginx from compose and delete nginx config.
6. Update README runtime/auth wording.
7. Run fixture test suite and compose config check.

## Verification

### Automated Check
Run fixture suite:

```sh
docker compose -f docker-compose.test.yml run --rm calibre-perl-server
```

Expected:

- all tests pass
- `/login` and `/logout` assertions expect `404`
- auth-on protected routes require Basic auth (`401` without header)

### Compose Check

```sh
docker compose config
```

Expected:

- only `calibre-perl-server` service present
- published port is `127.0.0.1:5000:5000`

### Manual Smoke
- start: `docker compose up`
- open `http://localhost:5000`
- with `users.sqlite` present, browser receives Basic auth challenge
- with valid creds, `/`, `/search`, `/book/:id`, `/cover/:id`, `/download/:id/:format`, and `/opds/*` work
- without `users.sqlite`, app is accessible anonymously

## Out Of Scope For V11
- adding TLS termination inside this repo
- re-introducing reverse proxy caching
- replacing Basic auth with token/OAuth flows
- reader-mode architecture changes
