# CPS V16 Plan: Random Books Homepage Section

## Goal

Add a lightweight homepage section showing 10 randomly selected books alongside the existing recent-books section.

Main targets:
- keep `Recent Books` deterministic and unchanged
- show a fresh random selection on each homepage request
- use the same book cards and reader-mode format links as other homepage sections
- avoid changing metadata or adding persistent random state

## Current Problem

The homepage currently shows recent books and the paginated library only. Users must search or browse pages to discover books that are not recent.

## V16 Changes

### 1. Add Random Book Query
Status: implemented.

Added `CalibreServer::DB::random_books($limit)` in `lib/CalibreServer/DB.pm`.

The query:
- returns the same book fields as `recent_books`
- applies existing display-title cleanup
- uses SQLite `ORDER BY RANDOM() LIMIT ?`
- defaults to 10 rows

The query is intentionally separate from recent-book ordering and does not mutate the database.

### 2. Load Ten Random Books On The Homepage
Status: implemented.

Updated `GET /` in `lib/CalibreServer.pm` to request exactly 10 random books.

Reader mode passes the random rows through `_with_formats`, matching the existing reader behavior for recent and library books.

### 3. Render Normal And Reader Sections
Status: implemented.

Added a `Random Books` section to:

- `views/index.tt`
- `views/index_reader.tt`

Normal mode uses the standard book-card partial. Reader mode uses the reader-book partial with cover slots and download format links.

### 4. Regression Coverage
Status: implemented.

Updated `t/web-reader.t` to assert that both normal and reader homepage responses include the `Random Books` section.

## Implementation Order

1. Add `random_books` to the DB layer.
2. Request 10 random rows from the homepage route.
3. Render the section in normal and reader templates.
4. Add homepage regression assertions.
5. Run the Dockerized test suite.

## Verification

### Automated Check

```sh
docker compose -f docker-compose.test.yml run --rm calibre-perl-server
```

Expected:
- all test files pass
- normal homepage contains `Random Books`
- reader homepage contains `Random Books`
- existing recent, library, search, and view-session behavior remains unchanged

### Manual Smoke Test

1. Open the homepage in normal mode.
2. Confirm 10 random book cards appear under `Random Books`.
3. Reload the homepage and confirm the selection can change.
4. Open reader mode and confirm random rows include the reader layout and available format links.

## Out Of Scope For V16

- replacing SQLite random ordering with a persistent recommendation system
- personalized recommendations
- random search results
- changing recent-books ordering
- adding new metadata fields or modifying Calibre's database
