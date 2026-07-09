# CPS V9 Plan: Generated Cover Thumbnails

## Goal
Reduce cover image payload size without modifying the Calibre library.

Main targets:
- keep original `cover.jpg` files untouched
- serve small grid thumbnails instead of full-size covers
- serve medium detail covers instead of full-size covers
- cache generated variants on disk
- keep nginx/browser caching simple

## Current Problem
`/cover/:id` serves the original Calibre `cover.jpg`.

Many covers are about `500KB` each. A grid page can therefore load many megabytes of images even with native `loading="lazy"`.

Lazy loading reduces when covers load, but it does not reduce the bytes for each cover.

## V9 Changes

### 1. Add Generated Cover Variants
Status: approved.

Add two new cover variants:

- `/cover/:id/thumb`
- `/cover/:id/medium`

Keep existing `/cover/:id` as the original-size route.

Why:
- grid pages need thumbnails, not original covers
- detail pages need larger covers, but still not originals
- keeping `/cover/:id` avoids breaking existing URLs

### 2. Use Conservative JPEG Sizes
Status: approved.

Start with JPEG only:

- `thumb`: fit inside `240x360`, quality `75`
- `medium`: fit inside `640x960`, quality `80`

Why:
- JPEG works everywhere
- no `Accept` negotiation
- no nginx cache variance by image format
- enough size reduction for the current problem

Expected rough sizes:

- `thumb`: `20KB` to `60KB`
- `medium`: `80KB` to `180KB`

### 3. Cache Generated Files On Disk
Status: implemented.

Store generated variants outside the Calibre library.

Default cache path:

```text
/tmp/cps-cover-cache
```

Optional runtime override:

```text
CPS_COVER_CACHE=/cover-cache
```

Cache file shape:

```text
$CPS_COVER_CACHE/:book_id/:variant.jpg
```

Why:
- originals stay read-only
- generation cost happens once per variant
- cache can later be mounted as a Docker volume if useful

### 4. Generate Variants On Demand
Status: implemented.

When `/cover/:id/thumb` or `/cover/:id/medium` is requested:

1. find the source Calibre `cover.jpg`
2. check whether the cached variant exists
3. if missing, generate it
4. return the cached variant with `image/jpeg`
5. if generation fails, return the original cover instead of a broken image

Why:
- no startup scan
- no background worker
- only covers users actually view are generated

### 5. Use `libvips` For Resizing
Status: implemented.

Use `libvips-tools`, specifically `vipsthumbnail`, if available.

Example shape:

```sh
vipsthumbnail SOURCE -s 240x360 -o DEST[Q=75]
```

Why:
- fast
- low memory
- simpler than adding a Perl image library

Fallback:
- do not add ImageMagick unless `libvips-tools` is unavailable or unsuitable

### 6. Update Templates To Use Variants
Status: implemented.

Change templates:

- `views/book_item.tt`: use `/cover/:id/thumb`
- `views/book.tt`: use `/cover/:id/medium`

Keep:

- `loading="lazy"`
- `decoding="async"`
- `fetchpriority="high"` for the detail page cover

Why:
- grid pages get the biggest byte savings
- detail pages still look good
- v8 native lazy loading remains intact

### 7. Keep Nginx Cover Caching
Status: implemented.

Reuse the v8 `/cover/` nginx location.

Generated variants should receive the same long cache treatment for successful `200` responses.

Why:
- nginx already owns browser/proxy cache headers
- variant URLs are stable
- no extra nginx route is needed

### 8. Do Not Add WebP Yet
Status: approved.

Skip WebP/AVIF for v9.

Why:
- requires format negotiation or `<picture>` markup
- nginx cache must vary by `Accept` or URL format
- JPEG thumbnails already solve most of the current payload problem

Add WebP later only if JPEG variants are still too large.

## Implementation Order
1. Add `libvips-tools` to the Docker image.
2. Add cover variant routing in `lib/CalibreServer.pm`.
3. Add disk-cache generation for `thumb` and `medium`.
4. Update templates to use variant URLs.
5. Bump `views/version.tt`.
6. Verify generated sizes and cache headers.

## Verification

### Automated Check
Run the fixture smoke suite:

```sh
docker compose -f docker-compose.test.yml up --build --abort-on-container-exit --exit-code-from calibre-perl-server
```

### Manual Smoke
- auth disabled: grid covers load from `/cover/:id/thumb`
- auth enabled anonymous: cover images are not rendered
- auth enabled logged in: grid/detail covers load from generated variants
- original `/cover/:id` still works

### Size Checks
Compare response sizes in browser DevTools or with curl:

- original `/cover/:id`: about `500KB`
- thumb `/cover/:id/thumb`: target `20KB` to `60KB`
- medium `/cover/:id/medium`: target `80KB` to `180KB`

### Cache Checks
- first variant request may be slower and show nginx `MISS`
- repeated variant request should show nginx `HIT`
- cached generated file should exist under `$CPS_COVER_CACHE`
