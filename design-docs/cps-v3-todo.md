# CPS V3 UI Todo

Based on `design-docs/cps-v3-plan.md`.

## Review And Preparation

1. Confirm the approved plan text in `design-docs/cps-v3-plan.md`.
2. Review each implementation step before editing templates.

## Implementation Tasks

### 1. Update `views/book_item.tt`

- Render book items in a responsive grid.
- Show 2 columns on mobile.
- Show 4 columns on desktop.
- Show the existing cover image when available.
- Add `loading="lazy"` and `decoding="async"` to cover images.
- When no cover exists, render a cover-sized light-blue placeholder block.
- Center the book title inside the placeholder.
- Clip placeholder text if it is too long.
- Keep the title as the main link.
- Keep authors directly below the title.
- Use only template markup plus inline `<style>` if needed.

### 2. Update `views/search.tt`

- Keep the search header concise.
- Make the search form the clear top action.
- Improve the grouping of the input and submit button.
- Render results with the updated `book_item.tt`.
- Keep page state obvious at a glance.
- Improve the no-query and no-results states.
- Improve previous/next pagination visibility.
- Avoid hiding important information or actions.

### 3. Update `views/book.tt`

- Add a `Back to library` link pointing to `/`.
- Rework the page into a clearer reading-first layout.
- Keep the cover near the main title/author content.
- Put download links in the title area so they are easy to find.
- Keep metadata grouped and easy to scan.
- Keep tags as secondary information.
- Render the description safely.
- Preserve description line breaks with escaped output.
- Use inline `<style>` only if markup alone is not enough.

### 4. Update `views/login.tt`

- Center the login content toward the top.
- Constrain the form width.
- Improve grouping of heading, error, fields, and submit button.
- Keep the existing hidden `return_url` field.
- Make the error message more visible.

## Review Workflow

1. Work on one todo at a time.
2. Show the exact template changes after each todo.
3. Wait for approval before moving to the next todo.
