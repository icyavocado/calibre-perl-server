# CPS V5 UI And Loading Plan

## Goal

Improve perceived speed and visual stability for book browsing with a few focused frontend-only tweaks:

- always reserve cover space with a styled fallback surface
- preload book pages on user intent
- format published dates more cleanly
- load visible covers first, then queue nearby offscreen covers in the background

Scope for this phase:

- templates
- CSS
- JavaScript

No backend changes in this phase.

## Current State

- `views/book_item.tt` renders a cover image when `book.has_cover`
- if no cover exists, it renders a placeholder block with the book title
- book detail page shows `Published:` using the raw database timestamp
- no site JavaScript exists yet
- cover images currently rely on native lazy loading

## Desired Outcome

### 1. Stable Cover Layout While Images Load

For books that have covers:

- render a placeholder-style background surface immediately
- show the book title centered and ellipsized inside that surface
- place the real cover image on top when it loads
- keep the cover area size fixed from the start so card alignment does not jump

For books without covers:

- keep using the placeholder-only surface

Goal:

- preserve layout consistency
- reduce visual shifting
- keep all cards aligned while images are still loading

### 2. Background Page Preload On Intent

When the user shows intent to open a book item:

- `hover`
- `focus`
- `touchstart`

preload only the target HTML page with a plain `fetch()`.

On mobile:

- preload visible book links on screen

Do not preload:

- cover images
- other page assets explicitly

Reason:

- the cover is already shared between the list and the book page
- keep preload behavior simple and low-risk

### 3. Better Published Date Formatting

Replace raw timestamps like:

- `2020-01-14 00:00:00+00:00`

with a friendlier format like:

- `January 14, 2020`

Constraint:

- template/CSS/JS only in this phase

Implementation direction:

- format the existing date string in the frontend layer rather than changing the backend query

### 4. Two-Phase Cover Loading

Replace the current passive-only lazy-loading behavior with a JS queue:

1. prioritize covers currently visible on screen
2. once visible covers are loaded, queue remaining covers in the background
3. load offscreen covers starting from the nearest ones first

Goal:

- faster initial rendering for what the user can actually see
- smoother scrolling because nearby covers are already warming in

## Proposed Implementation

### A. `views/book_item.tt`

Update the markup so each cover slot can support both:

- fallback title surface
- real image layered above it

Expected structure:

- cover container
- placeholder title layer
- image layer when `book.has_cover`

Book title behavior:

- centered in the placeholder
- ellipsized
- space reserved even before image load completes

The image should:

- start hidden or visually inactive until loaded
- become visible once load completes

### B. `public/css/app.css`

Add cover-slot styling for:

- fixed aspect ratio
- stacked placeholder and image layers
- ellipsized placeholder text
- smooth reveal of the loaded image
- no layout jump during image load

Keep the existing book card sizing behavior.

### C. `public/js/main.js`

Add a small site script with two responsibilities:

#### 1. Book page preload

- attach to book item links
- trigger `fetch()` on:
  - `mouseenter`
  - `focus`
  - `touchstart`
- avoid duplicate preloads for the same URL
- store prefetched HTML responses in memory by URL
- reuse prefetched HTML on click when available so navigation does not require a second fetch

#### 2. Cover loading queue

- identify book card cover images
- prioritize visible images first
- after visible images finish, continue loading offscreen images
- process nearest offscreen covers first

Expected behavior:

- visible covers load immediately
- remaining covers are progressively loaded in distance order
- queue should avoid spamming the browser with too many parallel requests

### D. `views/layouts/main.tt`

Load `js/main.js` with the same cache-busting pattern used for CSS.

Example direction:

- `/js/main.js?v=[% INCLUDE version.tt %]`

### E. `views/book.tt`

Update the published date display to render a formatted date.

Because this phase is frontend-only:

- prefer transforming the existing string at render time
- do not change the database query or backend data model

## Loading Strategy Notes

### Placeholder Behind Real Cover

This should not be a significant performance issue if implemented as:

- one cover wrapper
- one placeholder layer
- one image layer

This is mostly a visual stability improvement, not a heavy runtime feature.

### Prefetch Scope

Use plain `fetch()` only for HTML documents.
Do not try to preload:

- cover images
- CSS
- JS
- downloads

This keeps the behavior predictable and avoids overfetching.

### Queue Strategy

The JS queue should:

- detect visible cards first
- load visible images immediately
- then sort the remaining cards by distance from viewport
- continue background loading from nearest to farthest

This gives a smoother scrolling experience than raw native lazy loading alone.

## Risks

### 1. Overfetching On Hover

Aggressive hover/touch preload can fetch pages the user never opens.

Mitigation:

- preload only HTML
- deduplicate requests per URL
- avoid repeated fetches for the same item

### 2. Mobile Data Use

Preloading visible items on mobile may increase background traffic.

Mitigation:

- limit preload to visible links only
- avoid preloading linked assets separately

### 3. JS Queue Complexity

Custom image queueing is more complex than native lazy loading.

Mitigation:

- keep the queue small and purpose-built
- prioritize correctness and simplicity over clever heuristics

### 4. Date Parsing Edge Cases

Database timestamps may include timezone suffixes and full timestamps.

Mitigation:

- parse only the date portion needed for display
- degrade safely if a date is malformed

## Verification Plan

### Book Card Checks

1. cover slots keep their size before images load
2. placeholder title is visible until image appears
3. loaded image sits on top of the placeholder
4. title text in the placeholder is ellipsized cleanly

### Preload Checks

1. hovering a book item triggers one HTML preload
2. focusing a book item triggers one HTML preload
3. touchstart triggers preload on touch devices
4. duplicate hover/focus events do not repeatedly fetch the same URL
5. prefetched HTML is stored in memory for reuse
6. clicking a prefetched book item uses the stored HTML instead of triggering a second fetch when possible

### Date Checks

1. raw timestamp no longer appears on the book page
2. published date renders as `Month Day, Year`
3. malformed or empty dates do not break the page

### Cover Queue Checks

1. visible covers load first
2. nearby offscreen covers load next
3. scrolling feels smoother after the first batch
4. images are not requested repeatedly

## Proposed Execution Order

1. add `public/js/main.js`
2. load the script from `views/layouts/main.tt`
3. update `views/book_item.tt` cover structure
4. add layered cover styling in `public/css/app.css`
5. implement hover/focus/touch HTML preload
6. implement visible-first cover queue
7. update published date formatting in `views/book.tt`
8. verify desktop and mobile behavior

## Open Questions

1. The same placeholder-behind-image behavior should also apply to the large cover on `views/book.tt`.
2. The JS queue should use a hard cap of 4 concurrent background image loads.
3. On mobile, visible-link HTML preload should happen immediately on load.
