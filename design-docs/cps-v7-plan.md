# CPS V7 Infra Plan: DockerHub Publishing

## Goal
Publish the Docker image to DockerHub repo:
`icyavocado/calibre-perl-server`

## Tagging Strategy
- Always push `latest`
- Always push immutable tag based on commit SHA:
  - `icyavocado/calibre-perl-server:${GITHUB_SHA::7}`

## Architecture
- Build only `linux/amd64` (no multi-arch)

## Runtime Contract
Require mounting the Calibre library at `/calibre`:
- `/calibre/metadata.db` must exist
- `/calibre/users.sqlite` is optional (enables auth when present)

## CI Gate (must pass before pushing)
Run the existing fixture smoke suite via Docker:
`docker compose -f docker-compose.test.yml up --build --abort-on-container-exit --exit-code-from calibre-perl-server`

## GitHub Actions Workflow
- Trigger: push to `main` only
- Steps:
  1. `actions/checkout`
  2. run dockerized fixture smoke tests (gate)
  3. `docker login` to DockerHub using repository secrets
  4. build Docker image (amd64)
  5. push both tags:
     - `icyavocado/calibre-perl-server:latest`
     - `icyavocado/calibre-perl-server:${GITHUB_SHA::7}`

## Verification Plan
In CI logs, confirm:
- fixture test stage PASS
- Docker build succeeds
- push stage pushes `latest` and `${GITHUB_SHA::7}`

## Secrets
Use GitHub repository secrets:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## Notes
Docker build uses the default build context / Dockerfile in the repo root (`docker build .`).
