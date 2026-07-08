# CPS V4 Infra Plan

## Goal

Add nginx in front of the Perl app so static assets are easier to compress and cache, while keeping the existing application behavior intact.

Primary focus:

- gzip for frontend assets
- cache headers for static assets
- nginx as the public entrypoint
- minimal disruption to app behavior

## Current State

- The app is a single Perl/Starman container.
- Dancer2 serves HTML, OPDS, downloads, covers, and static files.
- Static assets live under `public/`.
- The app currently exposes port `5000` directly.
- No nginx layer exists today.
- No response compression layer exists today.

## Desired Outcome

Introduce nginx as the public entrypoint on port `80` inside the container while keeping host access on port `5000`.

nginx should:

- serve all files under `public/` directly
- gzip compress text-based assets and responses
- add cache headers for static assets
- proxy non-static requests to the Perl app
- preserve existing auth, redirects, downloads, cover serving, and OPDS behavior

The Perl app should:

- remain responsible for application routes and protected content
- stay on an internal Docker network
- no longer be published directly to the host in the normal compose flow
- stop handling `/public` asset paths
- clean up any Perl route or allowlist logic that still treats `/public` as a directly served path

## Recommended Architecture

Use two containers in `docker-compose.yml`:

1. `calibre-perl-server`
- runs the existing Starman app
- listens on internal port `5000`
- not bound directly to the host

2. `nginx`
- public-facing container
- listens on container port `80`
- published as `127.0.0.1:5000:80`
- serves `/app/public` directly
- proxies non-static requests to `calibre-perl-server:5000`

## Static Serving Plan

nginx should serve all static files rooted at `public/`.

Examples:

- `/css/pico.classless.min.css`
- `/css/app.css`
- `/favicon.ico`
- any future static assets placed under `public/`

Benefits:

- simpler compression
- simpler caching
- less unnecessary Perl app work for static requests

## Dynamic Routing Plan

Proxy these requests to the Perl app:

- `/`
- `/login`
- `/logout`
- `/search`
- `/book/:id`
- `/cover/:id`
- `/download/:id/:format`
- `/opds/...`

Keep `/download` proxied through the app because it depends on app logic and filesystem checks.

Cache behavior:

- nginx may use shared `proxy_cache` for safe read-only app routes in this phase
- `/login` and `/logout` should never use nginx `proxy_cache`
- `/download/:id/:format` should not use nginx `proxy_cache`
- cache keys must vary by auth state so anonymous and authenticated traffic do not share entries
- because the current app does not render user-specific HTML after login, authenticated read-only responses may share cache entries with other authenticated requests

For `/cover/:id`:

- request flow should still go through the Perl app
- nginx may proxy-cache cover responses only when cache keys vary by auth state
- anonymous and authenticated cover requests must not share cache entries

For HTML app routes such as `/`, `/search`, and `/book/:id`:

- shared proxy caching is allowed for read-only `GET` and `HEAD` traffic when cache keys vary by auth state
- authenticated traffic may share cache entries with other authenticated traffic
- login and logout responses should never be cached

## gzip Plan

Enable nginx gzip for compressible responses.

Recommended types:

- `text/css`
- `application/javascript`
- `application/json`
- `application/xml`
- `text/xml`
- `text/plain`
- `text/html`
- `image/svg+xml`

Recommended settings:

- `gzip on`
- `gzip_vary on`
- `gzip_proxied any`
- `gzip_min_length` set to a reasonable threshold
- `gzip_types` set explicitly

Notes:

- do not gzip already-compressed binary payloads such as JPEG covers, EPUB files, and most ebook download formats
- these formats usually gain little or nothing from gzip and only add CPU overhead
- better ways to make covers faster:
  1. add browser caching for `/cover/:id`
     - `Cache-Control`
     - `ETag` or `Last-Modified`
     - safe because that is per-browser, not shared proxy leakage
  2. let nginx serve the file after app auth check
     - app authorizes
     - app returns internal redirect like `X-Accel-Redirect`
     - nginx sends the actual `cover.jpg`
     - faster than Perl streaming it
  3. if auth is off, nginx proxy-cache covers
     - but not safe as shared cache when auth is on
- nginx can gzip proxied HTML too, not just static files

## Cache Header Plan

Because frontend assets already use versioned URLs via `views/version.tt`, nginx can cache static assets aggressively.

`views/version.tt` is not served or cached directly by nginx.
It is rendered by the Perl app into asset URLs such as `/css/app.css?v=...`, and nginx caches the resulting static asset request.

Recommended behavior for static files under `public/`:

- long-lived cache headers for versioned assets
- `Cache-Control: public`
- suitable expiration for CSS, JS, fonts, images, and similar static files

Recommended behavior for dynamic HTML and app routes:

- do not apply static-asset cache headers to app pages
- allow nginx `proxy_cache` for safe read-only routes except `/login`, `/logout`, and `/download/:id/:format`
- vary cache keys by auth state so anonymous and authenticated traffic do not share cache entries
- authenticated cache entries may be shared because the current app does not render user-specific HTML after login
- keep static asset caching under `public/` as the most aggressive cache policy

## Compose / Container Plan

### Perl App Container

Keep the current app image mostly unchanged.

Expected behavior:

- still listens on `5000`
- only reachable from nginx inside the compose network

### nginx Container

Use the standard nginx image with:

- mounted nginx config
- mounted project `public/` directory or repo root as needed
- upstream target of `calibre-perl-server:5000`
- host mapping `5000:80`

## Port Ownership

nginx is the public entrypoint inside the compose stack:

- nginx listens on port `80` in the container
- the host maps `5000` to nginx port `80`
- the Perl app continues listening on internal port `5000`

Compose direction:

- remove direct host binding from the app service
- publish nginx as `5000:80`

## Proxy Header Requirements

Pass through at least:

- `Host`
- `X-Forwarded-For`
- `X-Forwarded-Proto`
- `X-Real-IP`

Reason:

- preserve redirect host behavior
- keep future proxy-aware behavior straightforward

## Risks

### 1. Redirect Host/Port Behavior

If nginx does not pass `Host` correctly, login redirects may point to the wrong place.

Mitigation:

- explicitly pass `Host`
- verify login redirect flow through nginx

### 2. Authenticated Response Leakage

If nginx caches authenticated HTML in a shared cache, one user's logged-in page could be served to another request.

Mitigation:

- never cache `/login` or `/logout`
- do not proxy-cache `/download/:id/:format`
- vary cache keys by auth state
- verify that authenticated responses are not user-specific before sharing cached entries
- verify anonymous and authenticated requests do not share the same cache entry

### 3. Static Path Mapping Errors

The nginx root or alias must match the exact public paths used by templates.

Mitigation:

- map static paths directly to `public/`
- verify `/css/pico.classless.min.css` and `/css/app.css`

### 4. Port 5000 Mapping Drift

The host should still use port `5000`, but nginx should own it instead of the app container.

Mitigation:

- remove the app service host port binding
- publish nginx as `5000:80`
- verify the app is not exposed directly anymore

## Verification Plan

### Static Asset Checks

1. `/css/pico.classless.min.css` returns `200`
2. `/css/app.css` returns `200`
3. both return correct `Content-Type`
4. both return `Content-Encoding: gzip` when requested with gzip-capable headers
5. both return expected cache headers

### App Behavior Checks

1. `/` still redirects to login when auth is enabled
2. login flow still works
3. `/search` still works
4. `/book/:id` still works
5. `/cover/:id` still works
6. `/download/:id/:format` still works
7. OPDS endpoints still work

### Proxy Checks

1. redirects use the nginx-facing host/port correctly
2. no proxy loop
3. no broken static asset URLs
4. authenticated and anonymous requests do not share the same cache entry
5. login and logout responses are never served from proxy cache
6. download requests are not served from shared proxy cache
7. authenticated cached pages match fresh app responses

## Implementation Order

1. add nginx config
2. add nginx service to compose
3. mount `public/` into nginx
4. proxy app traffic to `calibre-perl-server:5000`
5. move public host binding to nginx as `5000:80`
6. enable gzip
7. add cache headers for static assets
8. add auth-state-aware proxy-cache rules for safe read-only routes
9. verify redirects, assets, cache behavior, auth behavior, and core routes
10. update README

## Future Follow-Ups

- add Brotli if desired later
- add more refined cache rules by file type
- add TLS termination if the deployment needs it
