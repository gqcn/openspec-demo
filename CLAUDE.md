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
make up           # AI-generated commit message + commit + push (requires claude CLI)
```

### Frontend (from apps/frontend/)
```bash
pnpm run build          # Production build (uses Turbo)
pnpm run build:antd     # Build Ant Design variant only
pnpm run lint           # ESLint
pnpm run check          # Type check
```

### Backend (from apps/backend/)
```bash
make build        # Compile to apps/backend/bin/platform
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
apps/backend/    → Go API server (GoFrame v2, port 8080)
apps/frontend/   → Vue 3 pnpm monorepo (Vite + Turbo, port 3002)
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

**Critical rules**:
1. When user reports bugs/issues/feedback (Chinese or English), invoke the `openspec-feedback` skill BEFORE making any code changes.

All artifact content in Simplified Chinese (except code identifiers, API paths, RFC keywords).

## GoFrame v2 Development Standards

**CRITICAL: All Go backend code MUST follow GoFrame v2 framework conventions. Use the `goframe-v2` skill for ALL backend development tasks.**

### When to Use goframe-v2 Skill

**MANDATORY** — Invoke the `goframe-v2` skill when:
- Writing or modifying any Go code in `apps/backend/`
- Implementing service layer logic (`internal/service/`)
- Creating new API endpoints or controllers
- Working with database operations (DAO/ORM)
- Implementing error handling, logging, or validation
- Managing configuration, context, or dependency injection
- Any Go backend development task

### Service Layer Requirements

Service layer code (`internal/service/`) MUST follow these patterns:

1. **Interface Definition**: Define service interfaces in `internal/service/{domain}/` with clear method signatures
2. **Implementation Structure**: Implement services with proper dependency injection via `s{ServiceName}` struct
3. **Context Management**: Always pass `ctx context.Context` as the first parameter
4. **Error Handling**: Use GoFrame's `gerror` package for structured error handling
5. **Logging**: Use `g.Log()` with proper context for all logging operations
6. **Configuration Access**: Use `g.Cfg()` for configuration retrieval
7. **Validation**: Use GoFrame's validation tags and `gvalid` package
8. **Transaction Management**: Use `g.DB().Transaction()` for multi-step operations

### Code Generation Workflow

1. **API Changes**: Modify `api/{resource}/v1/*.go` → run `make ctrl` to regenerate controllers
2. **Database Changes**: Update `manifest/sql/init.sql` → run `make dao` to regenerate DAO/Entity
3. **Service Changes**: Manually implement in `internal/service/` following GoFrame patterns

### Common Patterns

- **Service Registration**: Register services in `internal/logic/` with proper initialization
- **HTTP Response**: Use `g.RequestFromCtx(ctx).Response.WriteJson()` for JSON responses
- **Database Access**: Use `dao.{Entity}.Ctx(ctx)` for all database operations
- **Config Structure**: Define config structs matching `manifest/config/config.yaml` structure

## Key Conventions

- **Backend**: ALL Go code must use `goframe-v2` skill — no exceptions
- Frontend tables use VXE-Grid (`useVbenVxeGrid`) with Ant Design Vue components
- Backend controllers are auto-generated — edit `api/` DTOs, then run `make ctrl`
- DAO layer is auto-generated — modify DB schema, then run `make dao`
- E2E test files follow `TC####_description.ts` naming with sequential TC IDs
- DB: MySQL 8.0+, default connection in `apps/backend/manifest/config/config.yaml`
