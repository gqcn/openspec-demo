# Frontend UI Refactor: Migrate to Vben5 Framework

## Goal

Replace the current Element Plus-based frontend with a Vben5 (ruoyi-plus-vben5) framework-based frontend for a modern, professional admin UI. Keep all 4 existing pages functional, only upgrade the UI.

## Current State

- Vue 3 + Element Plus + Pinia + Axios + Vite
- 4 pages: Login, NotebookList, SpecManage, UserManage
- Simple MainLayout with sidebar + header
- GoFrame backend with JWT auth, response format `{code: 0, data: {...}}`

## Target State

- Vue 3 + Ant Design Vue + TailwindCSS + VXE Table + Vben5 layout system
- Same 4 pages, rewritten with new components
- BasicLayout (sidebar + header + tab bar)
- Dark mode, theme customization out of the box
- pnpm + Turborepo monorepo structure

## Architecture

```
frontend/
├── apps/
│   └── web-antd/src/
│       ├── views/_core/        # Login, 404, 403 (from Vben5)
│       ├── views/notebook/     # Notebook list (new)
│       ├── views/spec/         # Spec management (new)
│       ├── views/user/         # User management (new)
│       ├── api/                # Adapted for GoFrame backend
│       ├── router/             # Simplified to 4 pages
│       └── store/              # Auth store adapted
├── packages/                   # Vben5 shared packages (copied)
├── internal/                   # Build configs (copied)
└── turbo.json, pnpm-workspace.yaml
```

## Key Adaptations

1. **Auth**: Adapt login API to GoFrame format (`/api/auth/login` → `{code:0, data:{token,...}}`)
2. **Request Client**: Use Vben5 RequestClient, change success code check from 200 to 0
3. **Layout**: Use BasicLayout with 3 menu items (Notebooks, Specs, Users)
4. **Tables**: SpecManage and UserManage use VXE Table with VbenForm
5. **NotebookList**: Ant Design Vue Table + Cards, keep polling logic
6. **Removed**: All ruoyi business pages (roles, menus, depts, workflow, etc.)

## Build & Dev

- Package manager: pnpm (replaces npm)
- Dev: `pnpm dev` (Vite dev server)
- Proxy: `/api` → `http://localhost:8080`
- Makefile updated accordingly
