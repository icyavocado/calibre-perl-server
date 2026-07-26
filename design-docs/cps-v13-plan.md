# CPS V13 Plan: Display Title Cleanup and Auth Halt

## Goal
Clean up filename-polluted book titles in UI/OPDS output while keeping the library database read-only, and close the global auth gating bypass.

Main targets:
- strip leading `author_sort - ` from displayed titles
- keep series text in titles after author stripping
- avoid mutating `metadata.db`
- ensure unauthorized requests cannot render protected page bodies

## Current Problem
Many books in this library use filename-derived titles, for example:

- `LaHaye, Tim - Left Behind 09 - Assassins`

This makes list/search/book pages and OPDS feeds noisy because the author appears both in title and author fields.

Auth was also not fully enforced: the global `before` hook returned the auth error body, but did not halt dispatch, so protected routes could still render content with a 401 status.

## V13 Changes

### 1. Add display-title normalization helper
Status: implemented.

Added private helpers in `lib/CalibreServer/DB.pm`:

- `_name_key($value)` tokenizes and normalizes author names for fuzzy matching
- `_display_title($title, $author_sort)` removes a leading author prefix when safe

Behavior:
- exact, case-insensitive match on `author_sort . ' - '` strips the prefix
- fallback fuzzy match strips when tokenized left segment equals tokenized `author_sort`
- if stripped result is too short, returns original title

### 2. Apply normalization to DB read paths
Status: implemented.

Updated these query methods to select `books.author_sort` and rewrite returned `title` values through `_display_title`:

- `recent_books`
- `all_books`
- `search_books`
- `book_by_id`

Why:
- one canonical place for title cleanup
- templates and OPDS output benefit without duplicated view logic
- raw DB remains unchanged

### 3. Fix basic-auth gating bypass
Status: implemented.

In `lib/CalibreServer.pm`, `hook before` now uses `halt($auth_error)` instead of `return $auth_error` when `_require_basic_auth()` fails.

Why:
- `return` from Dancer2 `before` hook does not stop route dispatch
- `halt` guarantees protected route handlers do not run

### 4. Add regression tests
Status: implemented.

Added new unit test file `t/unit-title.t` for `_display_title` covering:
- exact author prefix stripping
- fuzzy author-prefix stripping (`Larsson, Stieg` vs `Stieg, Larsson,`)
- unchanged clean titles
- unchanged malformed/too-short strip cases

Updated `t/web-auth-on-anon.t`:
- assert unauthorized `/` body does not include `/book/:id` links
- assert `/login` and `/logout` now return `401` (gated before route lookup)

### 5. Cache bust version
Status: implemented.

Bumped `views/version.tt` from `20260725-1` to `20260725-2`.

## Implementation Order
1. Add `_name_key` and `_display_title` in DB layer.
2. Apply title normalization in list/search/book query methods.
3. Replace auth-hook `return` with `halt`.
4. Add title unit tests and auth regression assertions.
5. Bump version token.

## Verification

### Automated Check
Run fixture suite:

```sh
docker compose -f docker-compose.test.yml run --rm calibre-perl-server
```

Expected:
- all test files pass
- title helper tests pass
- unauthorized web responses do not leak protected page content

### Manual Smoke
- open `http://localhost:5000/` without credentials and confirm challenge/no page content
- open with valid Basic auth and confirm titles no longer show `Author - ...` prefix
- verify series fragments like `Left Behind 09 - Assassins` remain intact

## Out Of Scope For V13
- modifying `metadata.db` title data in Calibre
- series extraction into separate subtitle fields
- fixing missing physical book files for fixture-only metadata
