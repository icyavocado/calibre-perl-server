# CPS V12 Plan: Kobo-Style Reader View, Title Cleanup, Auth Halt

## Goal
Make reader mode render cleanly on e-reader browsers with a Kobo Shop-like list layout.

Main targets:
- use a dedicated reader layout instead of the normal site shell
- avoid modern CSS/JS features that break on older e-reader browsers
- show small cover thumbnails and tap-friendly download buttons
- keep reader mode focused on direct downloads, not book detail navigation
- strip leading `author_sort - ` prefixes from displayed titles without mutating `metadata.db`
- ensure unauthorized requests cannot render protected page bodies

## Current Problem
V10 reader templates changed content but still used the normal layout and assets:

- Pico classless CSS and app CSS are tuned for modern browsers
- app JS intercepts navigation for prefetch/history behavior
- old e-reader browsers can fail CSS variables and newer selectors

Result: reader pages render inconsistently and look broken on-device.

Many books also carry filename-derived titles (for example `LaHaye, Tim - Left Behind 09 - Assassins`), so author names appear twice in UI/OPDS output.

Auth gating also had a bypass risk: the global `before` hook returned auth error content but did not halt dispatch, so route handlers could still run under a 401 status.

## V12 Changes

### 1. Dedicated Reader Layout
Status: implemented.

Added `views/layouts/reader.tt` and rendered reader routes with `layout => 'reader'`.

Reader layout behavior:
- does not load `pico.classless.min.css`
- does not load `/css/app.css`
- does not load `/js/main.js`
- uses inline, simple, light-theme CSS only

Why:
- isolate reader pages from desktop-oriented assets
- reduce render and script complexity on e-ink browsers

### 2. Kobo-Style Reader List Rows
Status: implemented.

Added shared partial `views/reader_book.tt` and reused it in both reader templates.

Row shape:
- left: small cover thumbnail (`90x135`)
- right: title + author + download format buttons
- clear row separators and larger tap targets

Why:
- closer to Kobo store browsing behavior
- easier scanning and tapping on e-reader touch screens

### 3. Include Cover Thumbnails In Reader Mode
Status: implemented.

Reader rows now show `/cover/:id/thumb` when `book.has_cover` is true.
Fallback placeholder remains for books without covers.

Why:
- user requested a Kobo-Shop-like look, which is cover-forward

### 4. Reader-Specific Pagination Size
Status: implemented.

Changed reader-mode page sizing in routes:
- `/` library list: `20` books per page in reader mode (`100` otherwise)
- recent books on `/`: `5` in reader mode (`10` otherwise)
- `/search`: `20` results per page in reader mode (`10` otherwise)

Why:
- keeps page weight manageable now that reader mode includes covers
- reduces request bursts on slower e-reader networks

### 5. Reader Template Refresh
Status: implemented.

Updated:
- `views/index_reader.tt`
- `views/search_reader.tt`

Changes include:
- new header copy and mode-switch link
- boxed search form
- section styling hooks for reader layout
- button-like pagination links
- shared book row include

### 6. Regression Tests
Status: implemented.

Updated `t/web-reader.t` assertions:
- reader pages include cover thumbnail URLs
- reader pages do not load Pico CSS
- reader pages do not load app JS

Why:
- guards against accidentally reverting to the normal shell
- validates the new reader rendering contract

### 7. Cache Busting
Status: implemented.

Updated `views/version.tt` to `20260725-2` so frontend changes invalidate cached assets/pages.

### 8. Display-Title Normalization Helper
Status: implemented.

Added private helpers in `lib/CalibreServer/DB.pm`:

- `_name_key($value)` tokenizes and normalizes author names for fuzzy matching
- `_display_title($title, $author_sort)` removes a leading author prefix when safe
- `_books_has_author_sort()` caches schema detection for fixture compatibility

Behavior:
- exact, case-insensitive match on `author_sort . ' - '` strips the prefix
- fallback fuzzy match strips when tokenized left segment equals tokenized `author_sort`
- if stripped result is too short, returns original title

Why:
- cleans noisy filename-style titles while preserving data in `metadata.db`
- handles production DBs and fixture DBs (fixture schema lacks `books.author_sort`)

### 9. Apply Normalization To DB Read Paths
Status: implemented.

Updated these methods to provide `author_sort` and rewrite returned titles through `_display_title`:

- `recent_books`
- `all_books`
- `search_books`
- `book_by_id`

Why:
- one canonical cleanup path for UI and OPDS outputs
- avoids duplicated template logic

Note:
- search `WHERE` clauses intentionally still match raw `books.title`

### 10. Fix Basic-Auth Gating Bypass
Status: implemented.

In `lib/CalibreServer.pm`, changed the auth failure path in `hook before` from `return $auth_error` to `halt($auth_error)`.

Why:
- `return` from a Dancer2 `before` hook does not stop route dispatch
- `halt` guarantees protected route handlers do not execute on auth failure

### 11. Regression Tests
Status: implemented.

Added `t/unit-title.t` to cover title normalization behavior:
- exact author prefix stripping
- fuzzy author-prefix stripping (`Larsson, Stieg` vs `Stieg, Larsson,`)
- unchanged clean or malformed/too-short cases

Updated `t/web-auth-on-anon.t`:
- assert unauthorized `/` response body does not contain `/book/:id` links
- keep `/login` and `/logout` assertions at `404` (routes removed)

## Implementation Order
1. Add `reader.tt` layout.
2. Switch reader route rendering to `layout => 'reader'`.
3. Add shared `reader_book.tt` partial.
4. Restyle reader templates to Kobo-like list rows.
5. Add thumbnail covers and tune reader page sizes.
6. Update reader tests.
7. Bump `views/version.tt`.
8. Add title-normalization helpers in DB layer.
9. Apply title normalization in list/search/book query methods.
10. Replace auth-hook `return` with `halt`.
11. Add title unit tests and anon auth regression assertion.

## Verification

### Automated Check
Run fixture suite:

```sh
docker compose -f docker-compose.test.yml run --rm calibre-perl-server
```

Expected:
- all test files pass
- reader tests confirm cover thumbnails exist in reader HTML
- reader tests confirm no Pico CSS or app JS in reader HTML
- title helper tests pass
- unauthorized responses do not leak protected page content

### Manual Device Smoke
- open `/?view=reader` on Kobo/e-reader browser
- verify rows show cover + title + author + format buttons
- verify text stays dark on light background
- verify Previous/Next links are easy to tap
- verify `/search?view=reader&q=...` renders in the same style
- open `http://localhost:5000/` without credentials and confirm challenge with no library content
- open with valid Basic auth and confirm displayed titles no longer start with `Author - ` prefixes
- verify series fragments (for example `Left Behind 09 - Assassins`) remain intact

## Out Of Scope For V12
- OPDS visual changes
- grayscale-specific thumbnail variant
- dedicated reader-only routes
- replacing reader mode session preference behavior
- modifying `metadata.db` title values in Calibre
- extracting series text into a separate subtitle field
- fixing missing physical book files for fixture-only metadata
