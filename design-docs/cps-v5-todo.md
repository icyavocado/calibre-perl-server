# CPS V5 UI And Loading Todo

Based on `design-docs/cps-v5-plan.md`.

## Review Workflow

1. Work on one todo at a time.
2. Show the exact file changes after each todo.
3. Wait for approval before moving to the next todo.

## Implementation Tasks

### 1. Add `public/js/main.js` and load it from the layout

- Create `public/js/main.js`.
- Load it from `views/layouts/main.tt`.
- Use the same cache-busting pattern as CSS with `views/version.tt`.
- Do not add behavior yet beyond the minimal safe bootstrapping needed for later todos.

### 2. Update `views/book_item.tt` cover structure

- Add a wrapper that supports both placeholder and real cover image layers.
- Keep placeholder title visible behind the image while it loads.
- Keep title text centered and ellipsized.
- Preserve current links and accessibility text.

### 3. Update `views/book.tt` large cover structure

- Apply the same placeholder-behind-image pattern to the large cover on the book page.
- Keep the cover area size stable before the image loads.

### 4. Add layered cover styling in `public/css/app.css`

- Add fixed-size cover slot styling.
- Layer placeholder and image correctly.
- Reveal the image only after it has loaded.
- Preserve stable layout and card alignment.
- Keep placeholder text ellipsized and centered.

### 5. Implement HTML preload in `public/js/main.js`

- Trigger plain `fetch()` preload on `mouseenter`, `focus`, and `touchstart`.
- Store prefetched HTML responses in memory by URL.
- Reuse prefetched HTML on click when possible.
- Prevent duplicate fetches for the same URL.
- On mobile, preload visible book links immediately on load.

### 6. Implement the cover loading queue in `public/js/main.js`

- Prioritize visible cover images first.
- Then queue remaining offscreen covers by nearest distance from the viewport.
- Use a hard cap of 4 concurrent background image loads.
- Avoid repeated image requests.

### 7. Format the published date in `views/book.tt`

- Replace the raw database timestamp display with `Month Day, Year` formatting.
- Keep the change frontend-only.
- Degrade safely for malformed or empty dates.

### 8. Verify desktop and mobile behavior

- Confirm layout stability while covers load.
- Confirm preload behavior works without duplicate requests.
- Confirm visible-first cover loading works.
- Confirm published dates render correctly.
