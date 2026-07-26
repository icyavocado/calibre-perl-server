# CPS V14 Plan: Search Relevance Ranking

## Goal
Make search results rank by match quality so exact and word-level title matches show before loose substring matches.

Main targets:
- keep the existing search match scope (title/author/tags/comments/series)
- prioritize title relevance over import recency
- ensure `host` ranks `The Host` ahead of `Ghost Writer`
- show why each result matched (title/author/tag/series/description)

## Current Problem
Search currently matches with broad substring `LIKE` filters, then orders only by:

- `books.timestamp DESC`
- `books.id DESC`

That means newer books can rank above better matches. Example: searching `host` can show `Ghost`-type hits before `The Host`.

## V14 Changes

### 1. Add relevance rank in `search_books`
Status: implemented.

Updated `lib/CalibreServer/DB.pm` in `search_books` to compute a `rank` column with CASE tiers:

- rank 0: exact title match
- rank 1: title starts with query token
- rank 2: query appears as a whole word in title (space-boundary approximation)
- rank 3: title substring match
- rank 4: author match
- rank 5: tags/comments/series-only match

Then changed ordering to:

- `ORDER BY rank ASC, books.timestamp DESC, books.id DESC`

### 2. Keep matching behavior unchanged
Status: implemented.

The existing five-way `WHERE ... LIKE` filter remains intact. V14 changes ordering only; it does not remove any previously matched rows.

### 3. Show match reason labels in search results
Status: implemented.

Updated search output to render per-result labels such as:

- `[ Exact Title Matched ]`
- `[ Title Matched ]`
- `[ Author Matched ]`
- `[ Tag Matched ]`
- `[ Series Matched ]`
- `[ Description Matched ]`

Implemented by adding `match_reason` from `search_books` and rendering it in:

- `views/book_item.tt` (normal search)
- `views/reader_book.tt` (reader search)

Styling updates:

- `public/css/app.css` adds `.search-match-reason`
- `views/layouts/reader.tt` adds `.reader-match-reason`

### 4. Add regression data and test
Status: implemented.

Fixture updates in `test/fixtures/metadata.db`:
- added books `The Host` and `Ghost Writer`
- added `Ocean Tales` with comment text containing `host`
- linked minimal author rows for all added books

New test `t/web-search.t`:
- requests `/search?q=host`
- asserts both titles appear
- asserts `The Host` appears before `Ghost Writer` in rendered output
- asserts title and description match-reason labels are rendered

### 5. Version bump
Status: implemented.

Updated `views/version.tt` from `20260725-2` to `20260725-4`.

## Implementation Order
1. Add CASE-based ranking tiers to search query select/order.
2. Keep existing search filter scope unchanged.
3. Add `match_reason` and render reason labels in search templates.
4. Add fixture rows for host/ghost/description regression scenario.
5. Add web regression test for ordering and reason labels.
6. Bump version token.

## Verification

### Automated Check
Run fixture suite:

```sh
docker compose -f docker-compose.test.yml run --rm calibre-perl-server
```

Expected:
- all test files pass
- `/search?q=host` includes `The Host`, `Ghost Writer`, and `Ocean Tales`
- `The Host` appears before `Ghost Writer`
- match-reason labels are visible (including description match)

## Out Of Scope For V14
- adding user-selectable search sort modes
- replacing space-boundary approximation with full tokenizer/FTS
- changing homepage/library browse ordering
