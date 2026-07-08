# Calibre Perl Server V2 Plan

## Goal

Refresh the web UI styling with Pico.css v2 using the classless build.

Keep V2 small:

- no JavaScript framework
- no CSS build pipeline
- no Sass theme work
- no major UX redesign

V2 should improve the default look, spacing, typography, forms, and mobile behavior while keeping the current HTML-first Template Toolkit approach.

## Scope

V2 is only for web styling and light template structure cleanup.

Included:

- vendor Pico.css locally into `public/`
- use the classless build
- update the base layout to load Pico
- add missing document meta tags for responsive behavior
- adjust templates to use semantic HTML that Pico styles well

Not included:

- OPDS changes
- route changes unrelated to rendering
- auth behavior changes
- metadata model changes
- frontend build tooling
- custom theme system

## CSS Choice

Use Pico.css v2 classless, vendored locally.

Preferred file:

- `public/css/pico.classless.min.css`

Reasoning:

- fits the current semantic HTML approach
- avoids external CDN dependency
- keeps deployment self-contained
- keeps CSS assets organized under `public/css/`
- avoids introducing npm, Sass, or a compile step

Do not use the regular Pico build unless V2 later needs utility classes or component classes.

## Layout Changes

Update `views/layouts/main.tt`.

Add:

- `<html lang="en">`
- `<meta name="viewport" content="width=device-width, initial-scale=1">`
- `<meta name="color-scheme" content="light dark">`
- `<link rel="stylesheet" href="/css/pico.classless.min.css">`

Wrap page content in semantic landmarks so the classless build can style them predictably.

Preferred shell:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light dark">
  <title>...</title>
  <link rel="stylesheet" href="/css/pico.classless.min.css">
</head>
<body>
  <main>
    ...
  </main>
</body>
</html>
```

## Template Adjustments

### Home

Update `views/index.tt` to lean on semantic structure instead of bare spacing.

Suggested structure:

- page heading
- search form
- recent books section
- list of book summaries using the existing `book_item` partial

Prefer:

- `<header>` for page intro when useful
- `<section>` for recent books
- normal form controls without extra classes

### Search

Update `views/search.tt` similarly.

Keep:

- heading
- search form
- results list
- previous and next navigation

Use:

- semantic `<nav>` for pagination
- clearer empty-state text
- markup that works well on narrow screens without custom layout complexity

### Book Detail

Update `views/book.tt` to present metadata more cleanly.

Keep the page simple and readable:

- title
- cover image when available
- authors
- series
- tags
- comment/description
- download links

Prefer semantic grouping such as:

- `<header>` for title and primary metadata
- `<section>` blocks for description and downloads
- simple lists for tags and formats

### Login

Update `views/login.tt` only as needed.

Pico classless should already style:

- labels
- text inputs
- password input
- submit button

Keep any error display minimal and accessible.

### Error Pages

Keep `404` and `500` pages simple.

They should benefit automatically from the shared layout and Pico typography.

## Assets

Add the vendored Pico file to source control.

Expected public assets after V2:

- `public/css/pico.classless.min.css`

No asset pipeline is needed.

## Verification

Check these pages in a browser:

- `/`
- `/search?q=test`
- `/book/:id`
- `/login`
- not found page
- server error page if practical

Verify:

- responsive layout at mobile width
- readable typography and spacing
- form usability
- pagination readability
- cover images do not overflow layout
- long comments/descriptions remain readable
- dark and light mode remain acceptable through Pico defaults

## Implementation Order

1. Add `public/css/pico.classless.min.css`.
2. Update `views/layouts/main.tt` to load Pico and responsive meta tags.
3. Adjust `index.tt`, `search.tt`, `book.tt`, and `login.tt` to use semantic structure Pico styles well.
4. Verify pages on desktop and mobile widths.

## Success Criteria

V2 is done when:

- the app uses vendored Pico classless CSS
- the main pages render cleanly with Pico and semantic HTML
- forms and typography look good by default
- pages remain readable on mobile
- the code stays simple and static-file based
