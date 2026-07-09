# CPS V10 Plan: E-Reader List View

## Goal
Serve an image-free, plain list version of the site for e-reader browsers.

Main targets:
- auto-detect common e-reader browsers
- allow manual opt-in with `?view=reader`
- remember manual reader mode in the Dancer session
- keep the same URLs where possible
- skip book detail pages in reader mode
- show direct download links under each book

## Current Problem
The current web UI is cover-first and image-heavy. That is good for browsers, but bad for e-reader browsers:

- images are slow or wasteful
- modern CSS can render poorly
- small e-ink browsers need simple links
- users mostly want direct book downloads

## V10 Changes

### 1. Reader Mode Detection
Status: implemented.

Use both automatic and manual detection.

Automatic detection checks the `User-Agent` for common e-reader strings:

- `kindle`
- `kobo`
- `pocketbook`
- `boox`
- `onyx`
- `eink`
- `e-ink`
- `ereader`

Manual detection:

- `?view=reader` enables reader mode and stores it in the Dancer session
- `?view=normal` disables reader mode and clears it from the session

Reader mode is active when:

- the request has `?view=reader`
- the session has `reader_view`
- the `User-Agent` looks like an e-reader

Why:
- auto-detection handles real e-reader browsers
- manual mode gives users a reliable fallback
- opt-out avoids trapping users in reader mode

### 2. Add Reader Mode Links
Status: implemented.

On the normal index page, add this link:

```text
View library from e-reader
```

Target:

```text
/?view=reader
```

On reader pages, add this link:

```text
View normal site
```

Target:

```text
/?view=normal
```

Why:
- no new route is needed
- users can switch modes intentionally
- the link copy matches the requested wording

### 3. Add Image-Free Reader Templates
Status: implemented.

Add plain templates:

- `views/index_reader.tt`
- `views/search_reader.tt`

Reader list shape:

```text
Recent Books

Book Title
Author
EPUB | PDF | MOBI

Library

Book Title
Author
EPUB | PDF
```

Rules:

- no covers
- no book detail links as the primary action
- title and author are plain text
- format links point directly to `/download/:id/:format`

Why:
- e-reader browsers are narrow and slow
- direct download links avoid unnecessary navigation
- under-title links are easier to tap than one long row

### 4. Attach Formats For Reader Lists
Status: implemented.

Current list queries return book metadata but not formats. Reader mode needs download links per book.

Minimal approach:

- reuse `CalibreServer::DB::formats_for_book($id)`
- attach `formats` to each listed book only when rendering reader mode

Why:
- no SQL rewrite yet
- keeps normal mode untouched
- simple enough for `10` recent books and `100` library rows

Tradeoff:

- this is N+1 queries in reader mode
- optimize later only if it is actually slow

### 5. Reader Search
Status: implemented.

Keep the same `/search` route.

Reader search includes:

- plain search form
- result list
- direct format download links
- previous/next pagination

Pagination links do not need `view=reader` once the session is set, but keeping it is acceptable.

Why:
- same URL shape as the normal site
- search remains usable from e-reader browsers
- no dedicated `/reader/search` route needed

### 6. Reader Mode And Nginx Cache
Status: implemented.

Reader mode changes HTML for the same URL, so nginx must not serve normal HTML to reader sessions or reader HTML to normal sessions.

Implemented v10 cache rule:

- `/__auth_state` returns `X-Reader-Mode`
- anonymous nginx fast path computes reader mode from `User-Agent` and `view` query parameter
- nginx uses backend reader-mode headers when cookies require a backend auth-state check
- nginx includes reader mode in the HTML `proxy_cache_key`

Why:

- normal HTML and reader HTML cannot share a cache key
- manual `?view=reader` and `?view=normal` are safe
- e-reader `User-Agent` auto-detection is safe for anonymous requests
- reader pages are lightweight and image-free
- correctness matters more than caching reader HTML

### 7. Tests
Status: implemented.

Add fixture tests for reader mode.

Test cases:

- `GET /?view=reader` returns `200`
- reader index contains `Recent Books`
- reader index contains direct format links such as `EPUB`
- reader index does not contain `/cover/`
- after `GET /?view=reader`, later `GET /` with the session cookie still renders reader mode
- `GET /?view=normal` clears reader mode
- `GET /search?view=reader&q=fixture` renders reader search results

Why:
- covers the session behavior
- catches accidental image regressions
- verifies direct download links are present

### 8. Out Of Scope For V10
Status: accepted.

Do not add these in v10:

- dedicated `/reader` routes
- JavaScript detection
- OPDS changes
- CSS-heavy responsive redesign
- e-reader-specific authentication flow
- WebP/thumbnail changes

Why:
- same URLs plus server-side templates are enough
- fewer routes means fewer cache/auth edge cases
- v10 should ship the simple reader view first

## Implementation Order
1. Add reader-mode detection/session helpers.
2. Add reader-mode switch links.
3. Add reader templates.
4. Attach formats to books in reader mode.
5. Wire `/` and `/search` to switch templates when reader mode is active.
6. Add reader-mode tests.
7. Verify nginx behavior manually.

## Verification

### Automated Check
Run the fixture smoke suite:

```sh
docker compose -f docker-compose.test.yml up --build --abort-on-container-exit --exit-code-from calibre-perl-server
```

### Manual Smoke
- normal browser `/` still renders cover grid
- `/?view=reader` renders image-free list view
- reader mode persists on later `/` requests in the same session
- `/?view=normal` returns to normal view
- e-reader-like `User-Agent` renders reader view
- reader search works at `/search?q=fixture`

### Cache Checks
- normal page does not get reader HTML
- reader page does not get normal HTML
- `/cover/` is absent from reader HTML
