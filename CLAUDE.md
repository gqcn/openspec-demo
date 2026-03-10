# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI development training platform — manages JupyterLab dev machines on Kubernetes. Go backend (GoFrame v2) + Vue 3 frontend (Vben Admin monorepo) + Kind local K8s cluster.

## Common Commands

### Full-stack dev
```bash
make dev          # Start frontend (port 3002) + backend (port 8080)
make stop         # Stop both services
make status       # Show running status and log paths
```

### Frontend (from frontend/ or root)
```bash
pnpm run build          # Production build (uses Turbo)
pnpm run build:antd     # Build Ant Design variant only
pnpm run lint           # ESLint
pnpm run check          # Type check
```

### Backend (from backend/)
```bash
make build        # Compile to backend/bin/platform
make ctrl         # Generate controllers from API definitions
make dao          # Generate DAO/DO/Entity from DB schema
make service      # Generate service interfaces
```

### Kubernetes
```bash
make kind-setup     # Create Kind cluster + Ingress + NFS
make kind-teardown  # Destroy cluster
make k8s-preload    # Preload Jupyter images into Kind
```

### E2E Tests (from hack/tests/)
```bash
npx playwright test                   # Run all tests
npx playwright test TC0001            # Run a single test by TC ID
npx playwright test --headed          # With visible browser
npx playwright test --ui              # Interactive UI mode
```
Requires: Kind cluster + backend + frontend all running.

## Architecture

```
backend/         → Go API server (GoFrame v2, port 8080)
frontend/        → Vue 3 pnpm monorepo (Vite + Turbo, port 3002)
  apps/web-antd/ → Main app (Ant Design Vue)
  packages/      → Shared libs (@vben/*)
hack/            → Kind cluster setup scripts + E2E tests (Playwright)
openspec/        → OpenSpec change management artifacts
```

### Backend Structure (GoFrame v2 conventions)
- `api/{resource}/v1/` — Request/response DTOs with `g.Meta` tags (path, method)
- `internal/controller/` — HTTP handlers (auto-generated scaffolding via `make ctrl`)
- `internal/service/` — Business logic by domain (auth, user, spec, notebook, k8s)
- `internal/dao/` — Auto-generated data access layer (`make dao`)
- `internal/model/entity/` — Auto-generated DB entities
- `manifest/config/config.yaml` — Server, DB, JWT, K8s, notebook config
- `manifest/sql/init.sql` — Database schema (MySQL)

### Frontend Structure
- `apps/web-antd/src/api/` — API clients per domain
- `apps/web-antd/src/views/` — Page components per domain
- `apps/web-antd/src/preferences.ts` — App preference overrides
- Dev proxy: `/api` → backend:8080, `/jupyter` → platform.internal:80

### API Pattern
REST endpoints under `/api/`. Auth via JWT in `Authorization: Bearer` header. DTO naming: `CreateReq/CreateRes`, `ListReq/ListRes`. Three core resources: users, specs (machine resource definitions), notebooks (JupyterLab instances).

### K8s Integration
Backend manages JupyterLab pods in the `jupyter` namespace. Pod naming: `jupyterlab-{username}`. Access via Ingress at `{token}.platform.internal`. Notebook lifecycle: creating → running → stopping → stopped → failed.

## OpenSpec Workflow

This project uses OpenSpec-driven development. Changes live in `openspec/changes/`. Each change has: `proposal.md`, `design.md`, `specs/`, `tasks.md`.

**Critical rule**: When user reports bugs/issues/feedback (Chinese or English), invoke the `openspec-feedback` skill BEFORE making any code changes. Record issues in `tasks.md` first, then fix.

All artifact content in Simplified Chinese (except code identifiers, API paths, RFC keywords).

## Key Conventions

- Frontend tables use VXE-Grid (`useVbenVxeGrid`) with Ant Design Vue components
- Backend controllers are auto-generated — edit `api/` DTOs, then run `make ctrl`
- DAO layer is auto-generated — modify DB schema, then run `make dao`
- E2E test files follow `TC####_description.ts` naming with sequential TC IDs
- DB: MySQL 8.0+, default connection in `backend/manifest/config/config.yaml`
