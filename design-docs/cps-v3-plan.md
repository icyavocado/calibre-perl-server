# CPS V3 UI Plan

## Goal

Improve usability across the four core HTML templates, with a focus on clean, easy-to-view components:

- `views/book_item.tt`
- `views/book.tt`
- `views/search.tt`
- `views/login.tt`

The implementation should preserve the current server-rendered flow, stay compatible with Pico classless CSS, and avoid backend changes in this pass.

## Constraints

- Strictly template-only for this phase.
- No controller or DB query changes.
- Use Pico classless as the base.
- If classless markup is not enough, allow a small inline `<style>` block in the relevant template.
- Search and recent-book rows should show the existing book cover when it exists, without re-engineering cover handling.
- Thumbnails should use native lazy loading.
- If a cover does not exist, render a cover-sized `div` placeholder with:
  - a light blue background
  - the book title centered inside
  - text clipped if it is too long
- Book detail should prioritize reading and comprehension first, with downloads nearby.
- Description rendering should be safe.

## Current Data Limits

### `book_item.tt`

Receives `book` with:

- `id`
- `title`
- `authors`
- `has_cover`
- `timestamp`

### `search.tt`

Receives:

- `query`
- `page`
- `has_prev`
- `has_next`
- `recent_books` as the search result list

### `book.tt`

Receives:

- `book`
  - `id`
  - `title`
  - `authors`
  - `series`
  - `series_index`
  - `comment`
  - `pubdate`
  - `has_cover`
- `tags`
- `formats`

### `login.tt`

Receives:

- `return_url`
- `error`

## UX Direction

Keep the interface minimal but clearly usable:

- readable hierarchy
- faster scanning in result lists
- obvious navigation targets
- good mobile behavior
- no JavaScript
- native HTML behaviors where possible

## Template Plan

### 1. `views/book_item.tt`

Purpose:

- Make each result easier to scan.
- Add a clear visual anchor.
- Improve tap/click targets without adding backend dependencies.

Changes:

- Convert the item into a two-column summary row:
  - thumbnail area on the left
  - text/content on the right
- Show cover thumbnail when `book.has_cover`
- Use:
  - `loading="lazy"`
  - `decoding="async"`
  - meaningful `alt`
- Keep title as the primary link
- Show authors directly below title
- Provide a text-only placeholder block when no cover exists

Notes:

- Because this partial is also used on the home page, the result style should work for both "recent books" and search results.
- Since this is template-only, no richer metadata should be assumed beyond what already exists.

### 2. `views/search.tt`

Purpose:

- Make search feel like a complete workflow rather than just a form followed by a raw list.

Changes:

- Keep the header concise.
- Make the search form the primary entry point near the top.
- Group the query field and submit button more cleanly.
- When a query exists:
  - show a stronger results heading using the query
  - render results through the improved `book_item.tt`
- When there are no matches:
  - show a clearer empty state with guidance
- When there is no query yet:
  - show a lightweight prompt to search
- Improve pagination structure so previous/next is easier to notice and use
- Avoid hiding important information or actions; keep the page state obvious at a glance

Notes:

- There is no total count in the current backend response, so the UI should not promise counts or page totals.
- The variable is named `recent_books` in the template context even on search pages; that can stay as-is for this phase.

### 3. `views/book.tt`

Purpose:

- Make the detail page readable first.
- Keep downloads nearby without turning the page into a download-first layout.

Changes:

- Add a top link pointing to `/`, such as `Back to library`.
- Build a clearer reading layout:
  - title
  - authors
  - optional series line
  - cover placed nearby
  - metadata/details grouped cleanly
- Put download links in the title area so they are easy to find.
- Render formats as a clearer list of actions, while still using plain links.
- Keep tags as secondary metadata.
- Improve description readability with a dedicated section.

Safe rendering plan for description:

- Keep `book.comment` escaped by default.
- Preserve readable line breaks in the rendered output.
- Do not render raw Calibre HTML in this phase.

Recommended safe approach:

- Present the escaped text in a container styled with `white-space: pre-line` or `pre-wrap`.
- This preserves readability without trusting stored HTML.

Notes:

- This matches the safe-rendering requirement while staying template-only.
- Because there is no backend sanitization pipeline yet, raw HTML output should be avoided.

### 4. `views/login.tt`

Purpose:

- Make login feel focused and easier to use without diverging from the rest of the app.

Changes:

- Keep the form centered toward the top of the page.
- Add a constrained-width wrapper.
- Improve the visual grouping of:
  - heading
  - error state
  - username/password fields
  - submit button
- Keep `return_url` hidden input unchanged.
- Make the error message more visible and readable.

Notes:

- Since the preferred position is centered top, the layout should avoid full-screen centering and instead use a narrow top-aligned sign-in block.

## Styling Strategy

Default approach:

- rely on Pico classless markup and semantic elements first

Allowed fallback:

- a small inline `<style>` block inside the relevant template if needed for:
  - book list row layout
  - thumbnail sizing
  - login width/alignment
  - description whitespace handling
  - spacing for metadata/action groups

Avoid:

- global CSS refactors
- large custom class systems
- JavaScript behaviors

## Backend Suggestions For Later

Not in scope for this phase, but worth noting:

1. Search result data could expose more metadata for better list rows:
   - series
   - tags
   - pubdate
   - format count

2. Search could expose:
   - total result count
   - current result window

3. Book descriptions could support sanitized rich text if a safe rendering pipeline is added server-side.

## Proposed Execution Order

1. `book_item.tt`
2. `search.tt`
3. `book.tt`
4. `login.tt`
5. small inline style refinements only where markup alone is not enough
