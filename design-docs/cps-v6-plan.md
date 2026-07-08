# CPS V6 Testing Plan

## Goal

Add a very small, fast Perl-native test suite that covers the core app flows in both auth-disabled and auth-enabled modes, and make it runnable in CI.

This phase should focus on:

- fast route and integration tests
- fixture-backed deterministic test data
- the same route checks across auth states
- Docker-based test execution
- CI support

No frontend browser automation in this phase.

## Testing Direction

Stay Perl-native for maintainability.

Recommended stack:

- `Test::More`
- `Plack::Test`
- `HTTP::Request::Common`
- cookie/session handling helper if needed

Reason:

- matches the app language
- keeps dependencies small
- fast startup and execution
- enough for route, auth, redirect, and response validation

No Playwright or browser automation in this phase.

For V6, the server-side integration suite is the end-to-end layer.

## Scope

### In Scope

- Perl-native test harness
- fixture `metadata.db`
- fixture `users.sqlite`
- auth-disabled route coverage
- auth-enabled route coverage
- logged-in flow coverage
- Docker-based test execution
- GitHub Actions CI
- very small smoke-style suite

### Out Of Scope

- Playwright or browser automation
- frontend JS behavior tests
- visual regression tests
- large fixture libraries
- speculative test abstraction beyond what the first suite needs

## Fixture Strategy

Add a dedicated fixture library for tests, mounted inside Docker at `/fixtures`.

Recommended shape:

- `test/fixtures/metadata.db`
- `test/fixtures/users.sqlite`
- minimal book files and cover files only where required by tested routes

Goals:

- deterministic responses
- tiny test footprint
- fast local and CI execution

Fixture contents should stay intentionally small:

- a few books
- at least one book with a cover
- at least one downloadable format
- searchable title/author data
- at least one valid user in `users.sqlite`

## Runtime Strategy

Tests should run only through Docker, with the fixture library mounted at `/fixtures`.

The plan should avoid introducing a separate non-Docker test path in this phase.

Implementation direction:

- add a test-specific container or compose workflow
- mount the fixture library into the container at `/fixtures`
- point the app at `/fixtures` during test execution
- keep the normal `/calibre` production path unchanged outside the test workflow

## App Testability Adjustment

The app currently validates the Calibre library at module load time and expects the normal library path.

For test execution through Docker, the plan should introduce the smallest possible runtime path override so the app can run against `/fixtures` when invoked by the test workflow.

Requirements:

- production default path remains unchanged
- test mode can point at `/fixtures`
- no broad config system is needed just for V6

## Test Layers

### 1. Fast Integration Route Tests

Use PSGI-level tests to verify core HTTP behavior.

Primary targets:

- status codes
- redirects
- content types
- response body contains expected markers
- auth gating behavior
- session and login flow

### 2. Small Helper or Unit Tests

Add targeted unit tests only where they are cheap and useful.

Likely candidates:

- page number normalization
- MIME type mapping
- public path checks

Keep these small.
Do not over-invest if route-level tests already prove the behavior.

## Core Test Matrix

Run the same core smoke checks across three states:

1. auth disabled
2. auth enabled, not logged in
3. auth enabled, logged in

### Auth Disabled Expectations

- `/` returns `200`
- `/search?q=...` returns `200`
- `/book/:id` returns `200`
- `/cover/:id` returns `200` for a covered book
- `/download/:id/:format` returns `200`
- `/login` indicates auth is not needed or redirects away from login

### Auth Enabled, Not Logged In Expectations

- `/` redirects to `/login`
- `/search` redirects to `/login`
- `/book/:id` redirects to `/login`
- `/cover/:id` redirects to `/login`
- `/download/:id/:format` redirects to `/login`
- `/login` returns `200`

### Auth Enabled, Logged In Expectations

- login POST succeeds
- session persists across subsequent requests
- `/` returns `200`
- `/search?q=...` returns `200`
- `/book/:id` returns `200`
- `/cover/:id` returns `200`
- `/download/:id/:format` returns `200`

## Initial Minimal Test Cases

Start with a very small suite.

### Web Routes

1. home page
2. search
3. book detail
4. cover response
5. download response
6. login flow
7. pagination on `/`
8. pagination on `/search`

Only test behavior that already exists in the app today.

## Suggested Test File Layout

Example layout:

- `t/00-load.t`
- `t/lib/TestApp.pm`
- `t/lib/TestFixture.pm`
- `t/web-auth-off.t`
- `t/web-auth-on-anon.t`
- `t/web-auth-on-login.t`

Possible helper responsibilities:

- build the PSGI app under the fixture-backed Docker test environment
- provide common request helpers
- manage login session or cookies across requests
- centralize known fixture IDs and paths

## Docker Test Workflow

Recommended direction:

- add a Docker or compose-based test command
- mount the repo and `/fixtures` fixture library
- run the Perl test suite inside the container
- make the command usable both locally and in CI

The suite should not require the real `/home/dai/CalibreLibrary`.

## CI Plan

Use GitHub Actions.

CI responsibilities:

- build the Docker test environment
- mount or prepare the fixture library at `/fixtures`
- run the Perl-native test suite
- fail fast on regressions

Keep CI small and fast:

- one job first
- one Perl/runtime path first
- expand later only if needed

## Implementation Order

1. add fixture `metadata.db` and `users.sqlite`
2. add minimal fixture book files and cover files
3. add the smallest runtime path override needed for `/fixtures`
4. add Perl test dependencies
5. add test helper utilities
6. add auth-disabled smoke tests
7. add auth-enabled anonymous smoke tests
8. add auth-enabled logged-in smoke tests
9. add Docker test command or compose workflow
10. add GitHub Actions workflow
11. document how to run tests locally

## Risks

### 1. Hardcoded Calibre Path Assumptions

Current module-load validation is built around the default library path.

Mitigation:

- add the smallest fixture path override needed for Docker test execution

### 2. Session Handling In Tests

Logged-in flow needs reliable cookie persistence across requests.

Mitigation:

- use a helper that preserves cookies across requests

### 3. Fixture Drift

Real library behavior may differ from a tiny fixture.

Mitigation:

- keep the fixture representative enough for the tested routes
- avoid overfitting assertions to incidental HTML

### 4. False Browser Confidence

PSGI request tests are not real browser tests.

Mitigation:

- explicitly treat V6 as server-side integration coverage
- leave frontend/browser testing for a later phase

## Verification Plan

1. tests pass locally through Docker without using the real library
2. auth-off suite passes
3. auth-on anonymous suite passes
4. auth-on logged-in suite passes
5. GitHub Actions runs the same suite successfully
