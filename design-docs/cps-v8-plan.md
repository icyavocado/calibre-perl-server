# CPS V8 Plan: Faster Cover Delivery

## Goal
Make book covers load faster while reducing wasted nginx/app requests.

Main targets:
- avoid unnecessary `/__auth_state` upstream calls for cover-heavy pages
- avoid failed `/cover/:id` requests when auth is enabled and the user is anonymous
- cache cover responses longer than HTML
- simplify frontend cover loading so the browser does less work

## Current Problem

### Cover Loading
Covers used to be rendered as placeholders plus deferred image URLs:

```html
<img data-cover-src="/cover/:id" decoding="async">
```

`public/js/main.js` later assigned `img.src` through a custom queue. That gave control, but the queue scanned covers on page load, sorted by viewport distance, and woke on scroll/resize.

### Auth State
Nginx currently runs this for proxied app requests:

```nginx
auth_request /__auth_state;
```

That includes `/cover/:id`. A grid page can therefore cause many cover requests, and each cover request may also cause an auth-state subrequest.

## V8 Changes

### 1. Add Dedicated Nginx `/cover/` Handling
Add a `location /cover/` before the generic `/` location.

Use the same auth bucket separation as HTML, but give cover responses a longer cache lifetime:

Also make sure the auth bucket map reads `$auth_state`, because that is the value populated by `auth_request_set`:

```nginx
map $auth_state $auth_state_bucket {
  default anonymous;
  authenticated authenticated;
  anonymous anonymous;
  public public;
}
```

```nginx
map $status $cover_cache_control {
  default "no-store";
  200 "public, max-age=2592000";
  404 "public, max-age=600";
}

location /cover/ {
  auth_request /__auth_state;
  auth_request_set $auth_state $upstream_http_x_auth_state;

  proxy_cache calibre_cache;
  proxy_cache_methods GET HEAD;
  proxy_cache_key "$scheme$request_method$host$request_uri|$auth_state_bucket";
  proxy_cache_valid 200 30d;
  proxy_cache_valid 302 1m;
  proxy_cache_valid 404 10m;

  add_header Cache-Control $cover_cache_control always;
  add_header X-Proxy-Cache $upstream_cache_status always;
  add_header X-Auth-State-Bucket $auth_state_bucket always;

  proxy_set_header Host $http_host;
  proxy_set_header X-Forwarded-Host $http_host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_pass http://calibre_app;
}
```

Why:
- covers are more stable than HTML
- repeat page visits can reuse browser and nginx cache
- HTML cache policy stays separate

### 2. Add Anonymous Fast Path For `/__auth_state`
Avoid proxying to Perl when the request clearly has no cookie and no Basic Auth.

```nginx
map "$http_authorization:$http_cookie" $needs_auth_state_backend {
  default 1;
  ~^:$ 0;
}
```

Use `$upstream_http_x_auth_state` for proxied app auth responses. Nginx-local anonymous fast-path responses fall back to the auth bucket map's default `anonymous` value:

```nginx
auth_request_set $auth_state $upstream_http_x_auth_state;
```

```nginx
location = /__auth_state {
  internal;

  if ($needs_auth_state_backend = 0) {
    add_header X-Auth-State anonymous always;
    return 204;
  }

  proxy_pass http://calibre_app/__auth_state;
  proxy_pass_request_body off;
  proxy_set_header Content-Length "";
  proxy_set_header Host $http_host;
  proxy_set_header X-Forwarded-Host $http_host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
}
```

Why:
- anonymous traffic avoids one backend round trip per proxied request
- authenticated traffic still uses the app's existing auth logic
- treating any cookie as requiring backend validation is conservative and safe

### 3. Skip Cover Requests For Anonymous Users
Status: implemented.

When auth is enabled and the user is anonymous, do not load covers.

Do this in the templates by only rendering the cover `<img>` when the request is `public` or `authenticated`:

```tt2
[% IF book.has_cover && auth_state != 'anonymous' %]
  <img src="/cover/[% book.id %]" loading="lazy" decoding="async">
[% END %]
```

Why:
- avoids `/cover/:id` redirects/errors for anonymous users
- avoids wasting auth-state subrequests on covers that cannot be displayed
- keeps the existing placeholder visible
- removes cover-specific JavaScript entirely

### 4. Remove The JavaScript Cover Loader
Status: implemented.

Delete the custom cover queue from `public/js/main.js` and use browser-native image loading instead:

```html
<img src="/cover/:id" loading="lazy" decoding="async">
```

Why:
- less code
- no custom queue, scroll handler, image state, or error counter
- browser scheduling is good enough for this app

### 5. Prioritize Detail-Page Covers
Status: implemented.

In `views/book.tt`, mark the single detail cover as high priority:

```html
fetchpriority="high"
```

Keep grid/list covers normal priority.

Why:
- the detail page has one important cover
- the browser should fetch it before less important resources

### 6. Add Native Lazy-Loading Hint
Status: implemented.

Add this to cover images in `views/book_item.tt` and `views/book.tt`:

```html
loading="lazy"
```

Why:
- lets the browser schedule offscreen cover requests
- replaces the old JavaScript cover queue

### 7. Optional Backend Cache Header
Status: skipped.

Prefer nginx for cache headers. If nginx-only headers are not enough, add this inside the `/cover/:id` route in `lib/CalibreServer.pm`:

```perl
response_header 'Cache-Control' => 'public, max-age=2592000';
```

Skipped because nginx owns the public cover caching policy in this deployment.

## Implementation Order
1. Add nginx `/cover/` cache location.
2. Add anonymous fast path for `/__auth_state`.
3. Render cover `<img>` only when `auth_state` is not `anonymous`.
4. Remove the JavaScript cover loader and use native `loading="lazy"`.
5. Add `fetchpriority="high"` to the detail cover.
6. Verify behavior and cache headers.

## Verification

### Auth And Cache Correctness
- anonymous users do not receive authenticated covers
- authenticated users still see covers
- `/login` and `/logout` remain uncached
- HTML cache still varies by `$auth_state_bucket`

### Performance Checks
Use the browser Network tab:
- anonymous pages do not spam `/cover/:id`
- repeated authenticated page loads show cover cache hits
- repeated cover requests show `X-Proxy-Cache: HIT`
- `/__auth_state` upstream traffic drops for anonymous requests

### Automated Check
Run the fixture smoke suite:

```sh
docker compose -f docker-compose.test.yml up --build --abort-on-container-exit --exit-code-from calibre-perl-server
```

### Manual Smoke
- auth disabled: covers load and cache
- auth enabled anonymous: covers are skipped
- auth enabled logged in: covers load and cache
