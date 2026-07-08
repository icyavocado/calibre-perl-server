# CPS V6 Testing Todo

Based on `design-docs/cps-v6-plan.md`.

## Review Workflow

1. Work on one todo at a time.
2. Show the exact file changes after each todo.
3. Wait for approval before moving to the next todo.

## Implementation Tasks

### 1. Add fixture `metadata.db` and `users.sqlite`

- Create `test/fixtures/`.
- Add fixture `metadata.db`.
- Add fixture `users.sqlite`.
- Keep the fixture data intentionally small and deterministic.

### 2. Add minimal fixture book files and cover files

- Add only the files needed by tested routes.
- Include at least one cover image.
- Include at least one downloadable format file.

### 3. Add the smallest runtime path override needed for `/fixtures`

- Keep production defaults unchanged.
- Allow the Docker test workflow to point the app at `/fixtures`.
- Avoid introducing a broad configuration system.

### 4. Add Perl test dependencies

- Add the smallest needed Perl testing dependencies.
- Keep the dependency footprint light.

### 5. Add test helper utilities

- Add helper code for PSGI app bootstrapping in tests.
- Add helper code for common requests.
- Add helper code for cookie or session persistence.
- Centralize fixture IDs and paths used by tests.

### 6. Add auth-disabled smoke tests

- Verify the core routes under auth-disabled mode.
- Keep assertions minimal and stable.

### 7. Add auth-enabled anonymous smoke tests

- Verify redirects to login for protected routes.
- Verify login page availability.

### 8. Add auth-enabled logged-in smoke tests

- Verify login POST succeeds.
- Verify the session persists.
- Verify core routes after login.

### 9. Add Docker test command or compose workflow

- Run the test suite entirely through Docker.
- Mount fixtures at `/fixtures`.
- Avoid using the real library.

### 10. Add GitHub Actions workflow

- Run the same Docker-based test suite in CI.
- Keep the workflow small and fast.

### 11. Document how to run tests locally

- Add local test instructions.
- Keep them short and practical.
