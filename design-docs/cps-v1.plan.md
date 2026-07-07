# Calibre Perl Server V1 Plan

## Goals

Build a small read-only Calibre web and OPDS server in Perl.

Use:

- Dancer2 backend
- Template Toolkit frontend
- Calibre `/calibre/metadata.db`
- Optional Calibre `/calibre/users.sqlite`
- Docker and `docker-compose.yml`
- Fixed container path: `/calibre`

The app must be read-only and must not write to or modify `/calibre/metadata.db`.

The server should use little power, avoid background work, and support libraries up to roughly 50k books.

## Non-Goals

V1 will not include:

- Metadata editing
- Book upload or import
- In-browser reader
- Admin UI
- User creation UI
- Authors, tags, or series browse pages
- OPDS authors, tags, or series navigation
- Thumbnail cache
- Multiple library support
- Generated search indexes
- Any writes to the Calibre library database

## Fixed Paths

Inside the container:

```text
/calibre
/calibre/metadata.db
/calibre/users.sqlite
```

Rules:

- `/calibre` is required.
- `/calibre/metadata.db` is required.
- `/calibre/users.sqlite` is optional.
- If `/calibre/users.sqlite` exists, authentication is required.
- If `/calibre/users.sqlite` does not exist, the app runs without authentication.

No environment variables are required for V1.

## Docker

Do not use a `.env` file.

Do not require users to set environment variables.

`docker-compose.yml` should ask users to edit only the host-side library mount:

```yaml
services:
  calibre-perl-server:
    build: .
    ports:
      - "5000:5000"
    volumes:
      - /path/to/Calibre Library:/calibre:ro
```

The mounted Calibre library must contain `metadata.db`.

Users can enable authentication by creating `users.sqlite` in the same library directory before starting the container:

```sh
calibre-server --userdb "/path/to/Calibre Library/users.sqlite" --manage-users
```

The Docker container mounts the library read-only, so `users.sqlite` must be created or modified on the host.

## Authentication

Authentication is optional and controlled by the presence of `/calibre/users.sqlite`.

If the file exists:

- Web UI requires login.
- Covers require auth.
- Downloads require auth.
- OPDS requires HTTP Basic auth.

If the file does not exist:

- Web UI is open.
- Covers are open.
- Downloads are open.
- OPDS is open.

Use Calibre-compatible `users.sqlite`.

Calibre user table format:

```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    pw TEXT NOT NULL,
    timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
    session_data TEXT NOT NULL DEFAULT "{}",
    restriction TEXT NOT NULL DEFAULT "{}",
    readonly TEXT NOT NULL DEFAULT "n",
    misc_data TEXT NOT NULL DEFAULT "{}",
    UNIQUE(name)
);
```

V1 behavior:

- Validate username/password against `users.name` and `users.pw`.
- Web UI uses session login.
- OPDS uses HTTP Basic auth.
- Check `users.readonly`.
- Allow users with `readonly = "y"` because this app is read-only.
- Allow users with `readonly = "n"` because write-capable Calibre users can also read.
- Ignore Calibre restrictions for V1.

Use `Dancer2::Plugin::Auth::Tiny` for the web login unless it conflicts with the optional-auth behavior. Keep OPDS HTTP Basic simple and separate if needed.

## Startup Validation

On startup, fail fast with a clear error if:

- `/calibre` does not exist.
- `/calibre` is not readable.
- `/calibre/metadata.db` does not exist.
- `/calibre/metadata.db` is not readable.
- The app cannot bind to its configured HTTP port.

If `/calibre/users.sqlite` exists, fail fast with a clear error if:

- It is not readable.
- It does not contain a valid Calibre `users` table.

Do not create files or directories inside `/calibre`.

## Web Routes

```text
GET  /
GET  /search?q=...&page=1
GET  /book/:id
GET  /cover/:id
GET  /download/:id/:format
GET  /login
POST /login
POST /logout
```

If auth is enabled, the web UI uses a plain HTML login form at `/login` and stores successful login state in the Dancer2 session.

If auth is disabled, login and logout routes can redirect home or show a simple "auth disabled" page.

OPDS does not use the HTML login form. OPDS uses HTTP Basic auth when auth is enabled.

## OPDS Routes

The OPDS specs do not require a fixed URL path. This app uses versioned OPDS paths.

OPDS 1.x routes return Atom XML:

```text
GET /opds/v1
GET /opds/v1/
GET /opds/v1/recent
GET /opds/v1/search?query=...&page=1
GET /opds/v1/book/:id
```

OPDS 2.0 routes return JSON with media type `application/opds+json`:

```text
GET /opds/v2
GET /opds/v2/
GET /opds/v2/recent
GET /opds/v2/search?query=...&page=1
GET /opds/v2/book/:id
```

Support both OPDS 1.x and OPDS 2.0 in V1.

Use separate route prefixes instead of content negotiation:

- `/opds/v1` for OPDS 1.x Atom XML
- `/opds/v2` for OPDS 2.0 JSON

Use `query` as the OPDS search parameter.

If auth is enabled, every `/opds/v1*` and `/opds/v2*` route uses HTTP Basic auth.

## Web UI

Use plain HTML and minimal CSS.

Use Template Toolkit for rendering.

### Home Page

`/` shows:

- Search form
- Recent books
- Cover thumbnails when available
- Title
- Authors
- Available formats when cheap to load

### Search Page

`/search` searches:

- Title
- Authors
- Tags
- Comments
- Series

Results are paginated.

Each result should show:

- Cover thumbnail when available
- Title
- Authors
- Series when available
- Tags when available
- Available formats
- Link to book detail page

### Book Detail Page

`/book/:id` shows useful metadata available from the Calibre DB:

- Cover
- Title
- Authors
- Series
- Tags
- Comments or description
- Published date
- Available format download links

Show missing fields gracefully.

## OPDS

Support both OPDS 1.x and OPDS 2.0.

OPDS 1.x feeds return Atom XML.

OPDS 2.0 feeds return JSON with media type `application/opds+json`.

Feeds:

- Root feed
- Recent books feed
- Search feed
- Single-book acquisition feed

Each book entry should include:

- Title
- Authors
- Summary or comments when available
- Cover link when available
- Acquisition or download links for every available format

OPDS should reuse the same DB query layer as the web UI.

Use `XML::Writer` for OPDS 1.x XML generation.

Do not use `XML::Tiny` for OPDS generation because it is an XML parser, not an XML writer.

Use Dancer2 JSON serialization or `JSON::MaybeXS` for OPDS 2.0 JSON generation.

## Database Access

Use `DBI` and `DBD::SQLite`.

Open `/calibre/metadata.db` read-only.

Open `/calibre/users.sqlite` read-only when it exists.

Likely Calibre tables:

```text
books
authors
books_authors_link
books_tags_link
comments
series
```

No writes.

No migrations.

No cache tables.

No generated indexes in V1.

## Core DB Operations

The DB layer should provide small operations only:

- Get recent books.
- Search books.
- Get one book by id.
- Get authors for a book.
- Get tags for a book.
- Get comments for a book.
- Get series for a book.
- Get formats for a book.
- Resolve a cover path for a book.
- Resolve a download path for a book format.
- Validate a Calibre user when `users.sqlite` exists.

Avoid a large ORM or abstraction layer.

## Search

V1 search covers:

- Title
- Authors
- Tags
- Comments
- Series

Use SQL joins and `LIKE` queries.

Search comments too, but accept that comment search may be slower on large libraries.

If search is too slow later, add an optional external FTS index. Do not add it in V1.

## Pagination

Target library size: up to roughly 50k books.

Rules:

- Default page size: 50.
- Every list route uses `LIMIT` and `OFFSET`.
- Never load the full library into memory.
- Recent books use `books.timestamp` or `books.last_modified`.
- Search only runs after the user submits a query.
- Do not do background indexing.
- Do not generate thumbnails.

## Covers And Downloads

Calibre stores book-relative paths in `metadata.db`.

The app must resolve real files under `/calibre`.

Rules:

- Never accept file paths from request parameters.
- Resolve book paths only from Calibre DB rows.
- Join paths under `/calibre`.
- Verify the resolved absolute path stays under `/calibre`.
- Only serve formats listed in the `data` table.
- Only serve covers for books known in `books`.
- Only serve `cover.jpg` from the DB-known book directory.
- Require auth for covers and downloads when `/calibre/users.sqlite` exists.

## Security

Required V1 security behavior:

- Auth gate web, covers, downloads, and OPDS when `users.sqlite` exists.
- Path traversal protection for all file-serving routes.
- Do not expose arbitrary files from `/calibre`.
- Do not expose SQLite files for download.
- Do not log passwords.
- Do not write to Calibre DBs.
- Do not create sessions for failed logins.

## Perl Dependencies

Minimal `cpanfile` candidates:

```text
Dancer2
Dancer2::Plugin::Auth::Tiny
Template
DBI
DBD::SQLite
XML::Writer
JSON::MaybeXS
Plack
Starman
```

Keep dependencies minimal. Add more only when necessary.

## Proposed File Structure

```text
app.psgi
cpanfile
Dockerfile
docker-compose.yml
lib/CalibreServer.pm
lib/CalibreServer/DB.pm
lib/CalibreServer/Auth.pm
lib/CalibreServer/OPDS.pm
views/layouts/main.tt
views/index.tt
views/search.tt
views/book.tt
views/login.tt
public/app.css
README.md
```

This is a proposed structure, not a requirement. Prefer fewer files if implementation stays clear.

Do not add `config.yml` for V1. Use Dancer2 defaults unless explicit app configuration becomes necessary.

## Implementation Order

1. Add Dockerfile.
2. Add `docker-compose.yml`.
3. Mount the app source at `/app` in Docker for development.
4. Use `docker-compose` to create and run the Dancer2 app.
5. Create Dancer2 skeleton inside `/app`.
6. Add fixed-path startup validation.
7. Add read-only Calibre DB connection.
8. Add read-only Calibre query helpers.
9. Add optional `/calibre/users.sqlite` auth detection.
10. Add Calibre user validation.
11. Add web auth flow.
12. Add auth guard for protected web routes.
13. Add recent books page.
14. Add search page.
15. Add book detail page.
16. Add safe cover route.
17. Add safe download route.
18. Add OPDS HTTP Basic auth when auth is enabled.
19. Add OPDS v1 root/recent/search/book feeds.
20. Add OPDS v2 root/recent/search/book feeds.
21. Add README usage docs.
22. Smoke test no-auth mode.
23. Smoke test auth mode with Calibre-created `users.sqlite`.

## Smoke Tests

No-auth mode:

- Mount a Calibre library without `users.sqlite`.
- Confirm `/` loads without login.
- Confirm `/search?q=test` works.
- Confirm `/book/:id` works.
- Confirm `/cover/:id` works for books with covers.
- Confirm `/download/:id/:format` works.
- Confirm `/opds` works without HTTP Basic.

Auth mode:

- Create `users.sqlite` with `calibre-server --userdb ... --manage-users`.
- Mount the library read-only.
- Confirm `/` redirects to login or requires login.
- Confirm valid web login works.
- Confirm invalid web login fails.
- Confirm downloads require auth.
- Confirm `/opds` rejects missing HTTP Basic credentials.
- Confirm `/opds` accepts valid HTTP Basic credentials.

Security smoke tests:

- Try invalid book ids.
- Try invalid formats.
- Try path traversal-looking values in route params.
- Confirm SQLite files cannot be downloaded through download routes.

## Deferred Work

Add later only if needed:

- Calibre per-user restrictions.
- Authors, tags, and series browse pages.
- OPDS authors, tags, and series navigation.
- Multiple library support.
- Optional FTS search index.
- Thumbnail cache.
- In-browser reader.
- Metadata editing.
- Upload/import.
- Admin UI.
- User management UI.
