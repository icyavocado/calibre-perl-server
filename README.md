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

The public entrypoint is the Perl app on `http://localhost:5000`.

## Auth

If `/calibre/users.sqlite` exists, the app requires HTTP Basic auth.

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

## Test Suite (Fixtures)

Run the small Perl-native integration smoke suite against the fixture library.

```sh
docker compose -f docker-compose.test.yml up --build --abort-on-container-exit --exit-code-from calibre-perl-server
```

## Frontend Cache Busting

Stylesheet URLs include `?v=[% INCLUDE version.tt %]` from `views/version.tt`.

When frontend CSS changes are not appearing due to browser cache, update `views/version.tt` to a new value.

## Runtime

The app is served directly by Starman on port `5000` in Docker Compose.
