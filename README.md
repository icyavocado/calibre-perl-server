# Calibre Perl Server

Read-only Calibre web and OPDS server in Perl.

## Requirements

- Docker
- Docker Compose
- A Calibre library mounted at `/calibre`
- Optional `users.sqlite` in the same library folder to enable auth

## Docker

Edit `docker-compose.yml` and set the host Calibre library path:

```yaml
volumes:
  - /path/to/Calibre Library:/calibre:ro
```

Start the server:

```sh
docker compose up
```

The public entrypoint is nginx on `http://localhost:5000`.
The Perl app stays behind nginx on the internal compose network.

## Auth

If `/calibre/users.sqlite` exists, the app requires login.

Create or manage users with Calibre:

```sh
calibre-server --userdb /path/to/Calibre Library/users.sqlite --manage-users
```

If `users.sqlite` does not exist, the app runs without auth.

## Routes

Web:

- `/`
- `/search?q=...`
- `/book/:id`
- `/cover/:id`
- `/download/:id/:format`
- `/login`
- `/logout`

OPDS:

- `/opds/v1`
- `/opds/v1/recent`
- `/opds/v1/search?query=...`
- `/opds/v1/book/:id`
- `/opds/v2`
- `/opds/v2/recent`
- `/opds/v2/search?query=...`
- `/opds/v2/book/:id`

## Smoke Tests

No auth:

```sh
docker compose up
```

Auth enabled:

```sh
calibre-server --userdb /path/to/Calibre Library/users.sqlite --manage-users
docker compose up
```

Then confirm:

- `/` loads
- `/search` works
- `/book/:id` works
- `/cover/:id` works when the book has a cover
- `/download/:id/:format` downloads a format file
- `/opds/v1` and `/opds/v2` require HTTP Basic when auth is enabled

## Frontend Cache Busting

Stylesheet URLs include `?v=[% INCLUDE version.tt %]` from `views/version.tt`.

When frontend CSS changes are not appearing due to browser cache, update `views/version.tt` to a new value.

## nginx

nginx serves static files from `public/` directly and proxies dynamic app routes to the Perl app.

Current nginx responsibilities:

- serve static assets under `public/`
- gzip compress text responses
- add cache headers for static assets
- proxy dynamic routes to the Perl app
- maintain separate proxy-cache buckets for anonymous and authenticated read-only traffic

The app remains responsible for auth decisions, downloads, covers, and all dynamic route behavior.
