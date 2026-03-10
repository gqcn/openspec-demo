# Vben5 UI Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current Element Plus frontend with a Vben5-based frontend (Ant Design Vue + TailwindCSS + VXE Table) for a professional admin UI, while keeping all 4 existing pages functional.

**Architecture:** Copy the ruoyi-plus-vben5 monorepo framework into `frontend/`, strip all ruoyi business pages, then rewrite our 4 pages (Login, NotebookList, SpecManage, UserManage) using Vben5 component patterns. Use frontend-mode static routes (not backend-driven) since we only have 3 menu items.

**Tech Stack:** Vue 3, Ant Design Vue 4, TailwindCSS 3, VXE Table 4, Pinia, Vite 7, pnpm + Turborepo monorepo

---

## Task 1: Copy Vben5 Framework and Strip Business Pages

**Files:**
- Backup: `frontend/` → `frontend.bak/`
- Copy from: `/Users/john/Workspace/gitee/dapppp/ruoyi-plus-vben5/`
- Copy to: `frontend/`

**Step 1: Backup current frontend**

```bash
cd /Users/john/Workspace/github/gqcn/openspec-demo
mv frontend frontend.bak
```

**Step 2: Copy Vben5 framework (excluding .git, node_modules, docs, playground)**

```bash
mkdir frontend
# Copy root config files
for f in package.json pnpm-workspace.yaml turbo.json .npmrc .node-version .browserslistrc .editorconfig .gitignore .prettierrc.mjs .prettierignore eslint.config.mjs stylelint.config.mjs tsconfig.json; do
  cp "/Users/john/Workspace/gitee/dapppp/ruoyi-plus-vben5/$f" frontend/ 2>/dev/null || true
done

# Copy key directories
cp -R /Users/john/Workspace/gitee/dapppp/ruoyi-plus-vben5/packages frontend/
cp -R /Users/john/Workspace/gitee/dapppp/ruoyi-plus-vben5/internal frontend/
cp -R /Users/john/Workspace/gitee/dapppp/ruoyi-plus-vben5/scripts frontend/
mkdir -p frontend/apps
cp -R /Users/john/Workspace/gitee/dapppp/ruoyi-plus-vben5/apps/web-antd frontend/apps/
cp -R /Users/john/Workspace/gitee/dapppp/ruoyi-plus-vben5/apps/backend-mock frontend/apps/
```

**Step 3: Remove all ruoyi business pages and APIs from web-antd**

Delete these directories from `frontend/apps/web-antd/src/`:
- `views/system/` (all system management pages)
- `views/workflow/` (workflow)
- `views/tool/` (code generation)
- `views/monitor/` (monitoring)
- `views/demo/` (demo pages)
- `views/dashboard/` (dashboard - we'll recreate if needed)
- `api/system/` (all system APIs)
- `api/workflow/`
- `api/tool/`
- `api/monitor/`
- `components/dict/` (dictionary components)
- `components/tenant-toggle/` (multi-tenant)
- `store/dict.ts` (dictionary store)
- `store/notify.ts` (notification store)
- `store/tenant.ts` (tenant store)

Keep these:
- `views/_core/` (login, 404, 403 pages)
- `api/request.ts`, `api/helper.ts`, `api/index.ts`
- `api/core/` (auth, menu, user core APIs - we'll rewrite)
- `adapter/` (component, form, vxe-table adapters)
- `store/auth.ts` (we'll rewrite)
- `store/index.ts`
- `router/` (we'll rewrite)
- `layouts/` (we'll modify)
- `components/table/` (TableSwitch etc.)
- `components/global/`
- All config files

**Step 4: Remove the node_modules and lockfile that were copied (if any)**

```bash
rm -rf frontend/apps/web-antd/node_modules
rm -rf frontend/node_modules
rm -f frontend/pnpm-lock.yaml
```

**Step 5: Verify the directory structure is clean**

```bash
ls frontend/apps/web-antd/src/views/
# Should only show: _core/
ls frontend/apps/web-antd/src/api/
# Should show: core/ helper.ts index.ts request.ts
```

**Step 6: Commit**

```bash
git add frontend/
git commit -m "chore: copy Vben5 framework and strip ruoyi business pages"
```

---

## Task 2: Configure Root Files and Environment

**Files:**
- Modify: `frontend/apps/web-antd/.env`
- Modify: `frontend/apps/web-antd/.env.development`
- Modify: `frontend/apps/web-antd/vite.config.mts`
- Modify: `frontend/turbo.json`

**Step 1: Update `.env` (app identity)**

```env
# 应用标题
VITE_APP_TITLE=AI 训练平台

# 应用命名空间
VITE_APP_NAMESPACE=ai-training-platform

# store加密密钥
VITE_APP_STORE_SECURE_KEY=ai-training-platform-store-key
```

**Step 2: Update `.env.development` (dev settings)**

```env
# 端口号
VITE_PORT=3002

VITE_BASE=/
# 关闭 Mock
VITE_NITRO_MOCK=false
# 关闭 devtools
VITE_DEVTOOLS=false
# 注入全局loading
VITE_INJECT_APP_LOADING=true

# 后台请求路径
VITE_GLOB_API_URL=/api

# 关闭加密（我们的GoFrame后端不支持）
VITE_GLOB_ENABLE_ENCRYPT=false
VITE_GLOB_RSA_PUBLIC_KEY=
VITE_GLOB_RSA_PRIVATE_KEY=
# 不需要clientId
VITE_GLOB_APP_CLIENT_ID=

# 关闭SSE和WebSocket
VITE_GLOB_SSE_ENABLE=false
VITE_GLOB_WEBSOCKET_ENABLE=false
```

**Step 3: Update `vite.config.mts` (proxy to our backend without stripping /api)**

```typescript
import { defineConfig } from '@vben/vite-config';

export default defineConfig(async () => {
  return {
    application: {},
    vite: {
      server: {
        proxy: {
          '/api': {
            target: 'http://localhost:8080',
            changeOrigin: true,
            // Do NOT rewrite - our GoFrame backend expects /api prefix
          },
          '/jupyter': {
            target: 'http://platform.internal:80',
            changeOrigin: true,
            ws: true,
          },
        },
      },
    },
  };
});
```

**Step 4: Commit**

```bash
git add -A frontend/apps/web-antd/.env* frontend/apps/web-antd/vite.config.mts
git commit -m "chore: configure environment for AI training platform"
```

---

## Task 3: Adapt API Request Client for GoFrame Backend

**Files:**
- Rewrite: `frontend/apps/web-antd/src/api/request.ts`
- Rewrite: `frontend/apps/web-antd/src/api/helper.ts`
- Create: `frontend/apps/web-antd/src/api/common.ts`

**Step 1: Rewrite `api/request.ts`**

Key differences from ruoyi version:
- No encryption (remove RSA/AES logic)
- GoFrame response format: `{code: 0, data: {...}, message: "..."}` (code 0 = success, not 200)
- No clientId header
- Simpler error handling

```typescript
import type { RequestClientOptions } from '@vben/request';

import { useAppConfig } from '@vben/hooks';
import { preferences } from '@vben/preferences';
import {
  authenticateResponseInterceptor,
  errorMessageResponseInterceptor,
  RequestClient,
} from '@vben/request';
import { useAccessStore } from '@vben/stores';

import { message, Modal } from 'ant-design-vue';

import { useAuthStore } from '#/store/auth';

const { apiURL } = useAppConfig(import.meta.env, import.meta.env.PROD);

function createRequestClient(baseUrl: string) {
  const client = new RequestClient({
    baseURL: baseUrl,
  });

  // Request interceptor - add token
  client.addRequestInterceptor({
    fulfilled: async (config) => {
      const accessStore = useAccessStore();
      const token = accessStore.accessToken;

      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }

      // Add language header
      config.headers['Accept-Language'] = preferences.app.locale;

      return config;
    },
  });

  // Response interceptor - handle GoFrame response format
  client.addResponseInterceptor({
    fulfilled: (response) => {
      const { data: responseData, status } = response;

      // If response is a blob (file download), return directly
      if (
        responseData instanceof Blob ||
        response.config?.responseType === 'blob'
      ) {
        return response;
      }

      const { code, data, message: msg } = responseData;

      // GoFrame: code 0 = success
      if (code === 0) {
        return data;
      }

      // Business error
      throw new Error(msg || '请求失败');
    },
  });

  // Handle 401 unauthorized
  client.addResponseInterceptor(
    authenticateResponseInterceptor({
      client,
      doReAuthenticate: async () => {
        const accessStore = useAccessStore();
        const authStore = useAuthStore();
        accessStore.setAccessToken(null);

        if (preferences.app.loginExpiredMode === 'modal') {
          accessStore.setLoginExpired(true);
        } else {
          await authStore.logout();
        }
      },
      enableRefreshToken: false,
      formatToken: (token: string) => {
        return token ? `Bearer ${token}` : (token as any);
      },
    }),
  );

  // Error message interceptor
  client.addResponseInterceptor(
    errorMessageResponseInterceptor((msg: string, error) => {
      // Handle Axios error responses
      if (error?.response) {
        const { data } = error.response;
        // GoFrame error response
        if (data?.code === 401) {
          const accessStore = useAccessStore();
          const authStore = useAuthStore();
          accessStore.setAccessToken(null);
          authStore.logout();
          return;
        }
        message.error(data?.message || msg);
        return;
      }
      message.error(msg);
    }),
  );

  return client;
}

export const requestClient = createRequestClient(apiURL);

export const baseRequestClient = new RequestClient({ baseURL: apiURL });
```

**Step 2: Simplify `api/helper.ts`**

```typescript
export const ContentTypeEnum = {
  FORM_DATA: 'multipart/form-data;charset=UTF-8',
  FORM_URLENCODED: 'application/x-www-form-urlencoded;charset=UTF-8',
  JSON: 'application/json;charset=UTF-8',
};
```

**Step 3: Create `api/common.ts` with shared types**

```typescript
export type ID = number | string;
export type IDS = (number | string)[];

export interface PageQuery {
  page?: number;
  size?: number;
  [key: string]: any;
}

export interface PageResult<T> {
  list: T[];
  total: number;
}
```

**Step 4: Commit**

```bash
git add frontend/apps/web-antd/src/api/
git commit -m "feat: adapt API request client for GoFrame backend"
```

---

## Task 4: Create API Service Files

**Files:**
- Rewrite: `frontend/apps/web-antd/src/api/core/auth.ts`
- Rewrite: `frontend/apps/web-antd/src/api/core/user.ts`
- Delete: `frontend/apps/web-antd/src/api/core/menu.ts`
- Create: `frontend/apps/web-antd/src/api/notebook/index.ts`
- Create: `frontend/apps/web-antd/src/api/spec/index.ts`
- Create: `frontend/apps/web-antd/src/api/user/index.ts`
- Create: `frontend/apps/web-antd/src/api/image/index.ts`

**Step 1: Rewrite `api/core/auth.ts`**

```typescript
import { baseRequestClient, requestClient } from '#/api/request';

export namespace AuthApi {
  export interface LoginParams {
    username: string;
    password: string;
  }

  export interface LoginResult {
    token: string;
    userId: number;
    username: string;
    isAdmin: number;
    uid: number;
  }
}

/**
 * Login
 */
export async function loginApi(data: AuthApi.LoginParams) {
  return baseRequestClient.post<AuthApi.LoginResult>('/api/auth/login', data);
}

/**
 * Get current user info (used by Vben access system)
 */
export async function getUserInfoApi() {
  // Our backend doesn't have a separate userInfo endpoint
  // User info is returned at login and stored in localStorage
  // Return from localStorage
  const stored = localStorage.getItem('ai-platform-user');
  if (stored) {
    const user = JSON.parse(stored);
    return {
      user,
      roles: user.isAdmin === 1 ? ['admin'] : ['user'],
      permissions: user.isAdmin === 1
        ? ['notebook:list', 'spec:manage', 'user:manage']
        : ['notebook:list'],
    };
  }
  throw new Error('User not found');
}

/**
 * Logout
 */
export async function doLogout() {
  try {
    await requestClient.post('/auth/logout');
  } catch {
    // Ignore logout errors
  }
  localStorage.removeItem('ai-platform-user');
}

/**
 * Get menu list (not used - we use frontend routes)
 */
export async function getAllMenusApi() {
  return [];
}
```

**Step 2: Rewrite `api/core/user.ts`**

```typescript
export interface UserInfo {
  userId: number;
  username: string;
  realName: string;
  avatar: string;
  roles: string[];
  permissions: string[];
}

/**
 * Transform our backend user to Vben UserInfo format
 */
export function transformUserInfo(backendUser: {
  userId: number;
  username: string;
  isAdmin: number;
  uid: number;
}): UserInfo {
  return {
    userId: backendUser.userId,
    username: backendUser.username,
    realName: backendUser.username,
    avatar: '',
    roles: backendUser.isAdmin === 1 ? ['admin'] : ['user'],
    permissions: backendUser.isAdmin === 1
      ? ['notebook:list', 'spec:manage', 'user:manage']
      : ['notebook:list'],
  };
}
```

**Step 3: Create `api/notebook/index.ts`**

```typescript
import { requestClient } from '#/api/request';

export interface Instance {
  id: number;
  username: string;
  specId: number;
  specName: string;
  imageKey: string;
  imageName: string;
  image?: string;
  status: string;
  token: string;
  podIp: string;
  nodeName: string;
  accessUrl: string;
  lastActiveAt: string | null;
  createdAt: string;
}

export interface CreateNotebookReq {
  specId: number;
  imageKey: string;
}

export async function notebookList() {
  const res: any = await requestClient.get('/notebook');
  const list = (res?.list || []).map((item: any) => ({
    ...item,
    image: item.imageName || item.imageKey,
  }));
  return list as Instance[];
}

export async function notebookCreate(data: CreateNotebookReq) {
  return requestClient.post<Instance>('/notebook', data);
}

export async function notebookDelete(id: number) {
  return requestClient.delete(`/notebook/${id}`);
}

export async function notebookRestart(id: number) {
  return requestClient.post(`/notebook/${id}/restart`);
}
```

**Step 4: Create `api/spec/index.ts`**

```typescript
import type { PageResult } from '#/api/common';

import { requestClient } from '#/api/request';

export interface Spec {
  id: number;
  name: string;
  description: string;
  cpu: string;
  memory: string;
  gpu: number;
  gpuType: string;
  enabled: number;
  sortOrder: number;
  createdAt: string;
}

export interface CreateSpecReq {
  name: string;
  cpu: string;
  memory: string;
  gpu: number;
  gpuType: string;
}

export interface UpdateSpecReq {
  id: number;
  name?: string;
  cpu?: string;
  memory?: string;
  gpu?: number;
  gpuType?: string;
  enabled?: number;
}

export async function specList(page = 1, size = 20) {
  const res: any = await requestClient.get('/spec', {
    params: { page, size },
  });
  return {
    list: res?.list || [],
    total: res?.total || 0,
  } as PageResult<Spec>;
}

export async function specCreate(data: CreateSpecReq) {
  return requestClient.post<Spec>('/spec', data);
}

export async function specUpdate(data: UpdateSpecReq) {
  const { id, ...rest } = data;
  return requestClient.put(`/spec/${id}`, rest);
}

export async function specDelete(id: number) {
  return requestClient.delete(`/spec/${id}`);
}
```

**Step 5: Create `api/user/index.ts`**

```typescript
import type { PageResult } from '#/api/common';

import { requestClient } from '#/api/request';

export interface User {
  id: number;
  username: string;
  uid: number;
  isAdmin: number;
  status: number;
  createdAt: string;
}

export interface CreateUserReq {
  username: string;
  password: string;
  isAdmin: number;
}

export async function userList(page = 1, size = 20) {
  const res: any = await requestClient.get('/user', {
    params: { page, size },
  });
  return {
    list: res?.list || [],
    total: res?.total || 0,
  } as PageResult<User>;
}

export async function userCreate(data: CreateUserReq) {
  return requestClient.post('/user', data);
}

export async function userUpdate(
  id: number,
  data: { isAdmin?: number; password?: string },
) {
  return requestClient.put(`/user/${id}`, data);
}

export async function userStatusChange(id: number, status: number) {
  return requestClient.put(`/user/${id}/status`, { status });
}

export async function userDelete(id: number) {
  return requestClient.delete(`/user/${id}`);
}
```

**Step 6: Create `api/image/index.ts`**

```typescript
import { requestClient } from '#/api/request';

export interface ImageItem {
  key: string;
  name: string;
  image: string;
  description: string;
}

export async function imageList() {
  const res: any = await requestClient.get('/image');
  return (res?.list || []) as ImageItem[];
}
```

**Step 7: Commit**

```bash
git add frontend/apps/web-antd/src/api/
git commit -m "feat: create API service files for all endpoints"
```

---

## Task 5: Adapt Auth Store and Login Flow

**Files:**
- Rewrite: `frontend/apps/web-antd/src/store/auth.ts`
- Modify: `frontend/apps/web-antd/src/store/index.ts`

**Step 1: Rewrite `store/auth.ts`**

Adapt the Vben auth store pattern for our simpler auth flow:

```typescript
import type { UserInfo } from '#/api/core/user';

import { ref } from 'vue';
import { useRouter } from 'vue-router';

import { DEFAULT_HOME_PATH } from '@vben/constants';
import { resetAllStores, useAccessStore, useUserStore } from '@vben/stores';

import { message } from 'ant-design-vue';
import { defineStore } from 'pinia';

import { doLogout, getUserInfoApi, loginApi } from '#/api/core/auth';
import { transformUserInfo } from '#/api/core/user';

export const useAuthStore = defineStore('auth', () => {
  const accessStore = useAccessStore();
  const userStore = useUserStore();
  const router = useRouter();

  const loginLoading = ref(false);

  /**
   * Login
   */
  async function authLogin(
    params: { username: string; password: string },
    onSuccess?: () => Promise<void> | void,
  ) {
    try {
      loginLoading.value = true;

      // Call login API
      const result = await loginApi(params);

      // Store token
      accessStore.setAccessToken(result.token);

      // Store user info in localStorage for getUserInfoApi
      localStorage.setItem(
        'ai-platform-user',
        JSON.stringify({
          userId: result.userId,
          username: result.username,
          isAdmin: result.isAdmin,
          uid: result.uid,
        }),
      );

      // Transform and store user info
      const userInfo = transformUserInfo({
        userId: result.userId,
        username: result.username,
        isAdmin: result.isAdmin,
        uid: result.uid,
      });

      userStore.setUserInfo(userInfo as any);
      accessStore.setAccessCodes(userInfo.permissions);

      if (onSuccess) {
        await onSuccess?.();
        return;
      }

      message.success('登录成功');
      router.push(DEFAULT_HOME_PATH);
    } finally {
      loginLoading.value = false;
    }
  }

  /**
   * Logout
   */
  async function logout() {
    try {
      await doLogout();
    } catch {
      // Ignore logout errors
    }

    resetAllStores();
    accessStore.setLoginExpired(false);

    // Redirect to login
    await router.replace({
      path: '/auth/login',
    });
  }

  /**
   * Fetch user info (called by Vben access system on page refresh)
   */
  async function fetchUserInfo() {
    const result = await getUserInfoApi();

    const userInfo = transformUserInfo({
      userId: result.user.userId,
      username: result.user.username,
      isAdmin: result.user.isAdmin ?? 0,
      uid: result.user.uid ?? 0,
    });

    userStore.setUserInfo(userInfo as any);
    accessStore.setAccessCodes(userInfo.permissions);

    return userInfo;
  }

  return {
    authLogin,
    fetchUserInfo,
    loginLoading,
    logout,
  };
});
```

**Step 2: Simplify `store/index.ts`**

Remove dict, tenant, notify store imports. Keep only auth store initialization:

```typescript
import { initStores } from '@vben/stores';
import type { App } from 'vue';

export async function setupStore(app: App, options: { namespace: string }) {
  await initStores(app, options);
}

export { useAuthStore } from './auth';
```

**Step 3: Commit**

```bash
git add frontend/apps/web-antd/src/store/
git commit -m "feat: adapt auth store for GoFrame backend"
```

---

## Task 6: Configure Frontend Routes and Menu

**Files:**
- Rewrite: `frontend/apps/web-antd/src/router/access.ts`
- Rewrite: `frontend/apps/web-antd/src/router/routes/modules/` (remove all, create new)
- Modify: `frontend/apps/web-antd/src/router/routes/core.ts`
- Modify: `frontend/apps/web-antd/src/preferences.ts`

**Step 1: Update `preferences.ts` to use frontend route mode**

```typescript
import type { Preferences } from '@vben/preferences';

import { defineOverridesPreferences } from '@vben/preferences';

export const overridesPreferences = defineOverridesPreferences({
  app: {
    accessMode: 'frontend',  // Use frontend routes, not backend-driven
    enableRefreshToken: false,
    name: import.meta.env.VITE_APP_TITLE,
    defaultHomePath: '/notebooks',
  },
  footer: {
    enable: false,
  },
  tabbar: {
    persist: false,
  },
  theme: {
    semiDarkSidebar: true,  // Dark sidebar like the original design
    radius: '0.375',
  },
  sidebar: {
    width: 210,
  },
});
```

**Step 2: Create route module `router/routes/modules/platform.ts`**

```typescript
import type { RouteRecordRaw } from 'vue-router';

import { BasicLayout } from '#/layouts';

const platformRoutes: RouteRecordRaw[] = [
  {
    component: BasicLayout,
    meta: {
      icon: 'lucide:monitor',
      order: 1,
      title: '我的开发机',
    },
    name: 'Notebooks',
    path: '/notebooks',
    children: [
      {
        meta: {
          icon: 'lucide:monitor',
          title: '我的开发机',
          hideChildrenInMenu: true,
        },
        name: 'NotebookList',
        path: '',
        component: () => import('#/views/notebook/index.vue'),
      },
    ],
  },
  {
    component: BasicLayout,
    meta: {
      authority: ['spec:manage'],
      icon: 'lucide:cpu',
      order: 2,
      title: '规格管理',
    },
    name: 'Specs',
    path: '/specs',
    children: [
      {
        meta: {
          icon: 'lucide:cpu',
          title: '规格管理',
          hideChildrenInMenu: true,
        },
        name: 'SpecManage',
        path: '',
        component: () => import('#/views/spec/index.vue'),
      },
    ],
  },
  {
    component: BasicLayout,
    meta: {
      authority: ['user:manage'],
      icon: 'lucide:users',
      order: 3,
      title: '用户管理',
    },
    name: 'Users',
    path: '/users',
    children: [
      {
        meta: {
          icon: 'lucide:users',
          title: '用户管理',
          hideChildrenInMenu: true,
        },
        name: 'UserManage',
        path: '',
        component: () => import('#/views/user/index.vue'),
      },
    ],
  },
];

export default platformRoutes;
```

**Step 3: Remove old route modules**

Delete all files in `router/routes/modules/` except the new `platform.ts`.

**Step 4: Simplify `router/access.ts`**

Since we use frontend mode, simplify to just generate routes from static definitions:

```typescript
import type {
  ComponentRecordType,
  GenerateMenuAndRoutesOptions,
} from '@vben/types';

import { generateAccessible } from '@vben/access';
import { preferences } from '@vben/preferences';

import { BasicLayout, IFrameView } from '#/layouts';

const forbiddenComponent = () => import('#/views/_core/fallback/forbidden.vue');

async function generateAccess(options: GenerateMenuAndRoutesOptions) {
  const pageMap: ComponentRecordType = {};

  return await generateAccessible(preferences.app.accessMode, {
    ...options,
    fetchMenuListAsync: async () => {
      return [];
    },
    layoutMap: {
      BasicLayout,
      IFrameView,
    },
    pageMap,
    forbiddenComponent,
  });
}

export { generateAccess };
```

**Step 5: Commit**

```bash
git add frontend/apps/web-antd/src/router/ frontend/apps/web-antd/src/preferences.ts
git commit -m "feat: configure frontend routes with 3 menu items"
```

---

## Task 7: Simplify Layout

**Files:**
- Modify: `frontend/apps/web-antd/src/layouts/basic.vue`

**Step 1: Simplify `basic.vue`**

Remove tenant toggle, notification bell, and ruoyi-specific menu items. Keep the core layout with user dropdown:

```vue
<script setup lang="ts">
import type { NotificationItem } from '@vben/layouts';

import { computed } from 'vue';
import { useRouter } from 'vue-router';

import { AuthenticationLoginExpiredModal } from '@vben/common-ui';
import { preferences } from '@vben/preferences';
import { useAccessStore, useUserStore } from '@vben/stores';
import { openWindow } from '@vben/utils';

import { BasicLayout, LockScreen, UserDropdown } from '@vben/layouts';

import { $t } from '@vben/locales';
import { useAuthStore } from '#/store/auth';

const userStore = useUserStore();
const authStore = useAuthStore();
const accessStore = useAccessStore();
const router = useRouter();

const avatar = computed(() => {
  return userStore.userInfo?.avatar ?? preferences.app.defaultAvatar;
});
</script>

<template>
  <BasicLayout @clear-preferences-and-logout="authStore.logout()">
    <template #user-dropdown>
      <UserDropdown
        :avatar
        :description="userStore.userInfo?.username ?? ''"
        :text="userStore.userInfo?.realName ?? ''"
        tag-text="AI 训练平台"
      >
        <template #dropdown-menu>
          <!-- Can add custom menu items here -->
        </template>
      </UserDropdown>
    </template>
    <template #lock-screen>
      <LockScreen :avatar @to-login="authStore.logout()" />
    </template>
    <template #login-expired>
      <AuthenticationLoginExpiredModal
        v-if="accessStore.loginExpired"
        :avatar
        password-placeholder="请输入密码"
        username-placeholder="请输入用户名"
        @submit="authStore.authLogin"
      />
    </template>
  </BasicLayout>
</template>
```

**Step 2: Commit**

```bash
git add frontend/apps/web-antd/src/layouts/
git commit -m "feat: simplify layout for AI training platform"
```

---

## Task 8: Create Notebook List Page

**Files:**
- Create: `frontend/apps/web-antd/src/views/notebook/index.vue`
- Create: `frontend/apps/web-antd/src/views/notebook/create-modal.vue`
- Create: `frontend/apps/web-antd/src/views/notebook/data.ts`

**Step 1: Create `views/notebook/data.ts`**

```typescript
import type { VxeGridProps } from '#/adapter/vxe-table';

export const columns: VxeGridProps['columns'] = [
  { field: 'id', title: 'ID', width: 60 },
  { field: 'username', title: '用户名', width: 120 },
  { field: 'specName', title: '规格', width: 160 },
  {
    field: 'image',
    title: '镜像',
    minWidth: 200,
    showOverflow: true,
  },
  {
    field: 'status',
    title: '状态',
    width: 100,
    slots: { default: 'status' },
  },
  { field: 'nodeName', title: '节点', width: 120, showOverflow: true },
  { field: 'podIp', title: 'IP', width: 130 },
  { field: 'createdAt', title: '创建时间', width: 180 },
  {
    field: 'action',
    fixed: 'right',
    slots: { default: 'action' },
    title: '操作',
    width: 220,
  },
];

export const statusMap: Record<string, { label: string; color: string }> = {
  creating: { label: '创建中', color: 'processing' },
  running: { label: '运行中', color: 'success' },
  stopping: { label: '停止中', color: 'warning' },
  stopped: { label: '已停止', color: 'default' },
  failed: { label: '异常', color: 'error' },
};
```

**Step 2: Create `views/notebook/create-modal.vue`**

```vue
<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';

import { useVbenModal } from '@vben/common-ui';

import { Card, Col, Row, Select, SelectOption, Tag } from 'ant-design-vue';

import { specList, type Spec } from '#/api/spec';
import { imageList, type ImageItem } from '#/api/image';
import { notebookCreate } from '#/api/notebook';
import { message } from 'ant-design-vue';

const emit = defineEmits<{ reload: [] }>();

const specs = ref<Spec[]>([]);
const images = ref<ImageItem[]>([]);
const selectedSpecId = ref<number | null>(null);
const selectedImage = ref('');

onMounted(async () => {
  const [sr, ir] = await Promise.all([specList(1, 1000), imageList()]);
  specs.value = (sr.list || []).filter((s: Spec) => s.enabled === 1);
  images.value = ir || [];
});

const [BasicModal, modalApi] = useVbenModal({
  onConfirm: handleCreate,
  onOpenChange(isOpen) {
    if (isOpen) {
      selectedSpecId.value = null;
      selectedImage.value = '';
    }
  },
});

async function handleCreate() {
  if (!selectedSpecId.value) {
    message.warning('请选择规格');
    return;
  }
  if (!selectedImage.value) {
    message.warning('请选择镜像');
    return;
  }
  try {
    modalApi.lock(true);
    await notebookCreate({
      specId: selectedSpecId.value,
      imageKey: selectedImage.value,
    });
    message.success('开发机创建中，请稍候...');
    emit('reload');
    modalApi.close();
  } catch (e: any) {
    message.error(e?.message || '创建失败');
  } finally {
    modalApi.lock(false);
  }
}
</script>

<template>
  <BasicModal title="创建开发机" class="w-[680px]">
    <div class="mb-4">
      <div class="mb-3 font-semibold text-base">选择规格</div>
      <Row :gutter="[12, 12]">
        <Col v-for="spec in specs" :key="spec.id" :span="12">
          <Card
            hoverable
            :class="[
              'cursor-pointer transition-all',
              selectedSpecId === spec.id
                ? 'border-primary bg-primary/5'
                : '',
            ]"
            @click="selectedSpecId = spec.id"
          >
            <div class="font-semibold text-[15px]">{{ spec.name }}</div>
            <div class="mt-1 text-sm text-gray-500">
              <span>CPU: {{ spec.cpu }}</span>
              <span class="mx-2">内存: {{ spec.memory }}</span>
            </div>
            <div v-if="spec.gpu > 0" class="text-sm text-gray-500">
              GPU: {{ spec.gpu }}x {{ spec.gpuType }}
            </div>
            <div v-else class="text-sm text-gray-400">无 GPU</div>
          </Card>
        </Col>
      </Row>
    </div>

    <div>
      <div class="mb-3 font-semibold text-base">选择镜像</div>
      <Select
        v-model:value="selectedImage"
        placeholder="请选择镜像"
        class="w-full"
        size="large"
      >
        <SelectOption
          v-for="img in images"
          :key="img.key"
          :value="img.key"
        >
          <span class="font-semibold">{{ img.name }}</span>
          <span
            v-if="img.description"
            class="ml-2 text-xs text-gray-400"
          >
            {{ img.description }}
          </span>
        </SelectOption>
      </Select>
    </div>
  </BasicModal>
</template>
```

**Step 3: Create `views/notebook/index.vue`**

```vue
<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';

import { Page, useVbenModal } from '@vben/common-ui';
import { useAccessStore } from '@vben/stores';

import {
  Button,
  Popconfirm,
  Space,
  Table,
  Tag,
  Tooltip,
} from 'ant-design-vue';

import {
  notebookList,
  notebookDelete,
  notebookRestart,
  type Instance,
} from '#/api/notebook';
import { message } from 'ant-design-vue';

import { statusMap } from './data';
import CreateModal from './create-modal.vue';

const accessStore = useAccessStore();
const isAdmin = computed(() =>
  accessStore.accessCodes.includes('spec:manage'),
);

const notebooks = ref<Instance[]>([]);
const loading = ref(false);
let pollTimer: ReturnType<typeof setInterval> | null = null;

const hasActiveNotebook = computed(() =>
  notebooks.value.some((n) =>
    ['creating', 'running', 'stopping'].includes(n.status),
  ),
);

// Create modal
const [CreateNotebookModal, createModalApi] = useVbenModal({
  connectedComponent: CreateModal,
});

const tableColumns = computed(() => {
  const cols: any[] = [
    { title: 'ID', dataIndex: 'id', width: 60 },
  ];
  if (isAdmin.value) {
    cols.push({ title: '用户名', dataIndex: 'username', width: 120 });
  }
  cols.push(
    { title: '规格', dataIndex: 'specName', width: 160 },
    {
      title: '镜像',
      dataIndex: 'image',
      ellipsis: true,
    },
    {
      title: '状态',
      dataIndex: 'status',
      width: 100,
      key: 'status',
    },
    { title: '节点', dataIndex: 'nodeName', width: 120, ellipsis: true },
    { title: 'IP', dataIndex: 'podIp', width: 130 },
    { title: '创建时间', dataIndex: 'createdAt', width: 180 },
    {
      title: '操作',
      key: 'action',
      width: 220,
      fixed: 'right' as const,
    },
  );
  return cols;
});

async function fetchList() {
  loading.value = true;
  try {
    notebooks.value = await notebookList();
  } finally {
    loading.value = false;
  }
}

function needsPolling(list: Instance[]) {
  return list.some((n) =>
    ['creating', 'running', 'stopping'].includes(n.status),
  );
}

function startPoll() {
  if (pollTimer) return;
  pollTimer = setInterval(async () => {
    notebooks.value = await notebookList();
    if (!needsPolling(notebooks.value)) stopPoll();
  }, 5000);
}

function stopPoll() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

function watchPolling() {
  if (needsPolling(notebooks.value)) startPoll();
  else stopPoll();
}

function handleOpen(nb: Instance) {
  const url = `/jupyter/${nb.token}/lab`;
  window.open(url, '_blank');
}

async function handleRestart(nb: Instance) {
  try {
    await notebookRestart(nb.id);
    message.success('已发起重启');
    await fetchList();
    watchPolling();
  } catch (e: any) {
    message.error(e?.message || '操作失败');
  }
}

async function handleStop(nb: Instance) {
  try {
    await notebookDelete(nb.id);
    message.success('已停止');
    await fetchList();
    watchPolling();
  } catch (e: any) {
    message.error(e?.message || '操作失败');
  }
}

async function handlePurge(nb: Instance) {
  try {
    await notebookDelete(nb.id);
    message.success('记录已删除');
    await fetchList();
  } catch (e: any) {
    message.error(e?.message || '操作失败');
  }
}

async function onCreated() {
  await fetchList();
  startPoll();
}

onMounted(async () => {
  await fetchList();
  watchPolling();
});

onUnmounted(() => stopPoll());
</script>

<template>
  <Page
    title="我的开发机"
    content-class="p-4"
  >
    <template #extra>
      <Tooltip
        :title="
          hasActiveNotebook
            ? '您已有运行中的开发机，请先停止后再创建'
            : ''
        "
      >
        <Button
          type="primary"
          :disabled="hasActiveNotebook"
          @click="createModalApi.open()"
        >
          创建开发机
        </Button>
      </Tooltip>
    </template>

    <Table
      :columns="tableColumns"
      :data-source="notebooks"
      :loading="loading"
      :pagination="false"
      row-key="id"
      :scroll="{ x: 1200 }"
      bordered
      size="middle"
    >
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'status'">
          <Tag :color="statusMap[record.status]?.color || 'default'">
            {{ statusMap[record.status]?.label || record.status }}
          </Tag>
        </template>
        <template v-if="column.key === 'action'">
          <Space>
            <Button
              v-if="record.status === 'running'"
              type="link"
              size="small"
              @click="handleOpen(record)"
            >
              进入
            </Button>
            <Popconfirm
              v-if="record.status === 'running'"
              title="确认重启开发机吗？"
              @confirm="handleRestart(record)"
            >
              <Button type="link" size="small" class="text-orange-500">
                重启
              </Button>
            </Popconfirm>
            <Popconfirm
              v-if="
                !['stopped', 'stopping', 'failed'].includes(record.status)
              "
              title="确认停止开发机吗？"
              @confirm="handleStop(record)"
            >
              <Button type="link" size="small" danger>停止</Button>
            </Popconfirm>
            <Popconfirm
              v-if="['stopped', 'failed'].includes(record.status)"
              title="确认删除记录吗？此操作不可撤销。"
              @confirm="handlePurge(record)"
            >
              <Button type="link" size="small" danger>删除记录</Button>
            </Popconfirm>
          </Space>
        </template>
      </template>
    </Table>

    <CreateNotebookModal @reload="onCreated" />
  </Page>
</template>
```

**Step 4: Commit**

```bash
git add frontend/apps/web-antd/src/views/notebook/
git commit -m "feat: create notebook list page with Ant Design Vue"
```

---

## Task 9: Create Spec Management Page

**Files:**
- Create: `frontend/apps/web-antd/src/views/spec/index.vue`
- Create: `frontend/apps/web-antd/src/views/spec/spec-drawer.vue`
- Create: `frontend/apps/web-antd/src/views/spec/data.ts`

**Step 1: Create `views/spec/data.ts`**

```typescript
import type { FormSchemaGetter } from '#/adapter/form';
import type { VxeGridProps } from '#/adapter/vxe-table';

export const querySchema: FormSchemaGetter = () => [
  {
    component: 'Input',
    fieldName: 'name',
    label: '规格名称',
  },
];

export const columns: VxeGridProps['columns'] = [
  { field: 'id', title: 'ID', width: 60 },
  { field: 'name', title: '名称', width: 160 },
  { field: 'cpu', title: 'CPU', width: 100 },
  { field: 'memory', title: '内存', width: 100 },
  { field: 'gpu', title: 'GPU 数量', width: 90 },
  { field: 'gpuType', title: 'GPU 型号', width: 140 },
  {
    field: 'enabled',
    title: '状态',
    width: 90,
    slots: { default: 'status' },
  },
  { field: 'createdAt', title: '创建时间', width: 180 },
  {
    field: 'action',
    fixed: 'right',
    slots: { default: 'action' },
    title: '操作',
    width: 200,
  },
];

export const drawerSchema: FormSchemaGetter = () => [
  {
    component: 'Input',
    dependencies: {
      show: () => false,
      triggerFields: [''],
    },
    fieldName: 'id',
  },
  {
    component: 'Input',
    fieldName: 'name',
    label: '名称',
    rules: 'required',
    componentProps: {
      placeholder: '如: 4C8G',
    },
  },
  {
    component: 'Input',
    fieldName: 'cpu',
    label: 'CPU',
    rules: 'required',
    componentProps: {
      placeholder: '如: 4',
    },
  },
  {
    component: 'Input',
    fieldName: 'memory',
    label: '内存',
    rules: 'required',
    componentProps: {
      placeholder: '如: 8Gi',
    },
  },
  {
    component: 'InputNumber',
    fieldName: 'gpu',
    label: 'GPU 数量',
    defaultValue: 0,
    componentProps: {
      min: 0,
      max: 8,
    },
  },
  {
    component: 'Input',
    fieldName: 'gpuType',
    label: 'GPU 型号',
    componentProps: {
      placeholder: '如: nvidia.com/gpu',
    },
  },
];
```

**Step 2: Create `views/spec/spec-drawer.vue`**

```vue
<script setup lang="ts">
import { computed, ref } from 'vue';

import { useVbenDrawer } from '@vben/common-ui';

import { useVbenForm } from '#/adapter/form';
import { specCreate, specUpdate, type Spec } from '#/api/spec';
import { message } from 'ant-design-vue';

import { drawerSchema } from './data';

const emit = defineEmits<{ reload: [] }>();

const isUpdate = ref(false);
const title = computed(() => (isUpdate.value ? '编辑规格' : '新增规格'));

const [BasicForm, formApi] = useVbenForm({
  commonConfig: {
    componentProps: {
      class: 'w-full',
    },
    labelWidth: 80,
  },
  schema: drawerSchema(),
  showDefaultActions: false,
});

const [BasicDrawer, drawerApi] = useVbenDrawer({
  onConfirm: handleConfirm,
  onClosed() {
    formApi.resetForm();
  },
  async onOpenChange(isOpen) {
    if (!isOpen) return;
    drawerApi.drawerLoading(true);

    const data = drawerApi.getData() as { record?: Spec };
    isUpdate.value = !!data?.record;

    if (data?.record) {
      await formApi.setValues({
        id: data.record.id,
        name: data.record.name,
        cpu: data.record.cpu,
        memory: data.record.memory,
        gpu: data.record.gpu,
        gpuType: data.record.gpuType,
      });
    }

    drawerApi.drawerLoading(false);
  },
});

async function handleConfirm() {
  try {
    drawerApi.lock(true);
    const { valid } = await formApi.validate();
    if (!valid) return;

    const values = await formApi.getValues();

    if (isUpdate.value) {
      await specUpdate({ ...values });
      message.success('更新成功');
    } else {
      await specCreate(values);
      message.success('创建成功');
    }

    emit('reload');
    drawerApi.close();
  } catch (e: any) {
    message.error(e?.message || '操作失败');
  } finally {
    drawerApi.lock(false);
  }
}
</script>

<template>
  <BasicDrawer :title="title" class="w-[500px]">
    <BasicForm />
  </BasicDrawer>
</template>
```

**Step 3: Create `views/spec/index.vue`**

```vue
<script setup lang="ts">
import type { VbenFormProps } from '@vben/common-ui';
import type { VxeGridProps } from '#/adapter/vxe-table';
import type { Spec } from '#/api/spec';

import { Page, useVbenDrawer } from '@vben/common-ui';

import {
  Button,
  Modal,
  Popconfirm,
  Space,
  Tag,
} from 'ant-design-vue';

import { useVbenVxeGrid } from '#/adapter/vxe-table';
import { specList, specUpdate, specDelete } from '#/api/spec';
import { message } from 'ant-design-vue';

import { columns, querySchema } from './data';
import specDrawer from './spec-drawer.vue';

const formOptions: VbenFormProps = {
  schema: querySchema(),
  commonConfig: {
    labelWidth: 80,
    componentProps: {
      allowClear: true,
    },
  },
  wrapperClass: 'grid-cols-1 md:grid-cols-2 lg:grid-cols-3',
};

const gridOptions: VxeGridProps = {
  columns,
  height: 'auto',
  keepSource: true,
  pagerConfig: {},
  proxyConfig: {
    ajax: {
      query: async ({ page }) => {
        const result = await specList(page.currentPage, page.pageSize);
        return {
          rows: result.list,
          total: result.total,
        };
      },
    },
  },
  rowConfig: {
    keyField: 'id',
  },
  id: 'spec-manage-index',
};

const [BasicTable, tableApi] = useVbenVxeGrid({
  formOptions,
  gridOptions,
});

const [SpecDrawer, specDrawerApi] = useVbenDrawer({
  connectedComponent: specDrawer,
});

function handleAdd() {
  specDrawerApi.setData({});
  specDrawerApi.open();
}

function handleEdit(row: Spec) {
  specDrawerApi.setData({ record: row });
  specDrawerApi.open();
}

async function handleToggleStatus(row: Spec) {
  const newEnabled = row.enabled === 1 ? 0 : 1;
  const label = newEnabled === 1 ? '启用' : '禁用';
  try {
    await specUpdate({ id: row.id, enabled: newEnabled });
    message.success(`已${label}`);
    await tableApi.query();
  } catch (e: any) {
    message.error(e?.message || '操作失败');
  }
}

async function handleDelete(row: Spec) {
  try {
    await specDelete(row.id);
    message.success('已删除');
    await tableApi.query();
  } catch (e: any) {
    message.error(e?.message || '删除失败');
  }
}
</script>

<template>
  <Page :auto-content-height="true">
    <BasicTable table-title="规格列表">
      <template #toolbar-tools>
        <Space>
          <Button type="primary" @click="handleAdd">新增规格</Button>
        </Space>
      </template>
      <template #status="{ row }">
        <Tag :color="row.enabled === 1 ? 'success' : 'default'">
          {{ row.enabled === 1 ? '启用' : '禁用' }}
        </Tag>
      </template>
      <template #action="{ row }">
        <Space>
          <Button type="link" size="small" @click="handleEdit(row)">
            编辑
          </Button>
          <Popconfirm
            :title="`确认${row.enabled === 1 ? '禁用' : '启用'}吗？`"
            @confirm="handleToggleStatus(row)"
          >
            <Button type="link" size="small">
              {{ row.enabled === 1 ? '禁用' : '启用' }}
            </Button>
          </Popconfirm>
          <Popconfirm
            title="确认删除吗？"
            @confirm="handleDelete(row)"
          >
            <Button type="link" size="small" danger>删除</Button>
          </Popconfirm>
        </Space>
      </template>
    </BasicTable>
    <SpecDrawer @reload="tableApi.query()" />
  </Page>
</template>
```

**Step 4: Commit**

```bash
git add frontend/apps/web-antd/src/views/spec/
git commit -m "feat: create spec management page with VXE Table"
```

---

## Task 10: Create User Management Page

**Files:**
- Create: `frontend/apps/web-antd/src/views/user/index.vue`
- Create: `frontend/apps/web-antd/src/views/user/user-drawer.vue`
- Create: `frontend/apps/web-antd/src/views/user/data.ts`

**Step 1: Create `views/user/data.ts`**

```typescript
import type { FormSchemaGetter } from '#/adapter/form';
import type { VxeGridProps } from '#/adapter/vxe-table';

export const querySchema: FormSchemaGetter = () => [
  {
    component: 'Input',
    fieldName: 'username',
    label: '用户名',
  },
];

export const columns: VxeGridProps['columns'] = [
  { field: 'id', title: 'ID', width: 60 },
  { field: 'username', title: '用户名', width: 150 },
  { field: 'uid', title: 'UID', width: 90 },
  {
    field: 'isAdmin',
    title: '角色',
    width: 90,
    slots: { default: 'role' },
  },
  {
    field: 'status',
    title: '状态',
    width: 90,
    slots: { default: 'status' },
  },
  { field: 'createdAt', title: '创建时间', width: 180 },
  {
    field: 'action',
    fixed: 'right',
    slots: { default: 'action' },
    title: '操作',
    width: 200,
  },
];

export const createSchema: FormSchemaGetter = () => [
  {
    component: 'Input',
    fieldName: 'username',
    label: '用户名',
    rules: 'required',
    componentProps: {
      placeholder: '请输入用户名',
    },
  },
  {
    component: 'InputPassword',
    fieldName: 'password',
    label: '密码',
    rules: 'required',
    componentProps: {
      placeholder: '请输入密码',
    },
  },
  {
    component: 'RadioGroup',
    fieldName: 'isAdmin',
    label: '角色',
    defaultValue: 0,
    componentProps: {
      buttonStyle: 'solid',
      optionType: 'button',
      options: [
        { label: '普通用户', value: 0 },
        { label: '管理员', value: 1 },
      ],
    },
  },
];

export const editSchema: FormSchemaGetter = () => [
  {
    component: 'Input',
    dependencies: {
      show: () => false,
      triggerFields: [''],
    },
    fieldName: 'id',
  },
  {
    component: 'Input',
    fieldName: 'username',
    label: '用户名',
    componentProps: {
      disabled: true,
    },
  },
  {
    component: 'InputPassword',
    fieldName: 'password',
    label: '新密码',
    componentProps: {
      placeholder: '留空则不修改密码',
    },
  },
  {
    component: 'RadioGroup',
    fieldName: 'isAdmin',
    label: '角色',
    componentProps: {
      buttonStyle: 'solid',
      optionType: 'button',
      options: [
        { label: '普通用户', value: 0 },
        { label: '管理员', value: 1 },
      ],
    },
  },
];
```

**Step 2: Create `views/user/user-drawer.vue`**

```vue
<script setup lang="ts">
import { computed, ref } from 'vue';

import { useVbenDrawer } from '@vben/common-ui';

import { useVbenForm } from '#/adapter/form';
import { userCreate, userUpdate, type User } from '#/api/user';
import { message } from 'ant-design-vue';

import { createSchema, editSchema } from './data';

const emit = defineEmits<{ reload: [] }>();

const isUpdate = ref(false);
const title = computed(() => (isUpdate.value ? '编辑用户' : '新增用户'));

const [BasicForm, formApi] = useVbenForm({
  commonConfig: {
    componentProps: {
      class: 'w-full',
    },
    labelWidth: 80,
  },
  schema: createSchema(),
  showDefaultActions: false,
});

const [BasicDrawer, drawerApi] = useVbenDrawer({
  onConfirm: handleConfirm,
  onClosed() {
    formApi.resetForm();
  },
  async onOpenChange(isOpen) {
    if (!isOpen) return;
    drawerApi.drawerLoading(true);

    const data = drawerApi.getData() as { record?: User };
    isUpdate.value = !!data?.record;

    // Switch between create and edit schemas
    if (isUpdate.value && data?.record) {
      formApi.setState({ schema: editSchema() });
      await formApi.setValues({
        id: data.record.id,
        username: data.record.username,
        isAdmin: data.record.isAdmin,
        password: '',
      });
    } else {
      formApi.setState({ schema: createSchema() });
    }

    drawerApi.drawerLoading(false);
  },
});

async function handleConfirm() {
  try {
    drawerApi.lock(true);
    const { valid } = await formApi.validate();
    if (!valid) return;

    const values = await formApi.getValues();

    if (isUpdate.value) {
      const payload: { isAdmin?: number; password?: string } = {
        isAdmin: values.isAdmin,
      };
      if (values.password) payload.password = values.password;
      await userUpdate(values.id, payload);
      message.success('用户信息已更新');
    } else {
      await userCreate(values);
      message.success('用户创建成功');
    }

    emit('reload');
    drawerApi.close();
  } catch (e: any) {
    message.error(e?.message || '操作失败');
  } finally {
    drawerApi.lock(false);
  }
}
</script>

<template>
  <BasicDrawer :title="title" class="w-[450px]">
    <BasicForm />
  </BasicDrawer>
</template>
```

**Step 3: Create `views/user/index.vue`**

```vue
<script setup lang="ts">
import type { VbenFormProps } from '@vben/common-ui';
import type { VxeGridProps } from '#/adapter/vxe-table';
import type { User } from '#/api/user';

import { Page, useVbenDrawer } from '@vben/common-ui';

import {
  Button,
  Popconfirm,
  Space,
  Tag,
} from 'ant-design-vue';

import { useVbenVxeGrid } from '#/adapter/vxe-table';
import { userList, userStatusChange, userDelete } from '#/api/user';
import { message } from 'ant-design-vue';

import { columns, querySchema } from './data';
import userDrawer from './user-drawer.vue';

const formOptions: VbenFormProps = {
  schema: querySchema(),
  commonConfig: {
    labelWidth: 80,
    componentProps: {
      allowClear: true,
    },
  },
  wrapperClass: 'grid-cols-1 md:grid-cols-2 lg:grid-cols-3',
};

const gridOptions: VxeGridProps = {
  columns,
  height: 'auto',
  keepSource: true,
  pagerConfig: {},
  proxyConfig: {
    ajax: {
      query: async ({ page }) => {
        const result = await userList(page.currentPage, page.pageSize);
        return {
          rows: result.list,
          total: result.total,
        };
      },
    },
  },
  rowConfig: {
    keyField: 'id',
  },
  id: 'user-manage-index',
};

const [BasicTable, tableApi] = useVbenVxeGrid({
  formOptions,
  gridOptions,
});

const [UserDrawer, userDrawerApi] = useVbenDrawer({
  connectedComponent: userDrawer,
});

function handleAdd() {
  userDrawerApi.setData({});
  userDrawerApi.open();
}

function handleEdit(row: User) {
  userDrawerApi.setData({ record: row });
  userDrawerApi.open();
}

async function handleToggleStatus(row: User) {
  const newStatus = row.status === 1 ? 0 : 1;
  const label = newStatus === 1 ? '启用' : '禁用';
  try {
    await userStatusChange(row.id, newStatus);
    message.success(`已${label}`);
    await tableApi.query();
  } catch (e: any) {
    message.error(e?.message || '操作失败');
  }
}

async function handleDelete(row: User) {
  try {
    await userDelete(row.id);
    message.success('用户已删除');
    await tableApi.query();
  } catch (e: any) {
    message.error(e?.message || '删除失败');
  }
}
</script>

<template>
  <Page :auto-content-height="true">
    <BasicTable table-title="用户列表">
      <template #toolbar-tools>
        <Space>
          <Button type="primary" @click="handleAdd">新增用户</Button>
        </Space>
      </template>
      <template #role="{ row }">
        <Tag :color="row.isAdmin === 1 ? 'orange' : 'blue'">
          {{ row.isAdmin === 1 ? '管理员' : '普通用户' }}
        </Tag>
      </template>
      <template #status="{ row }">
        <Tag :color="row.status === 1 ? 'success' : 'default'">
          {{ row.status === 1 ? '正常' : '禁用' }}
        </Tag>
      </template>
      <template #action="{ row }">
        <Space>
          <Button type="link" size="small" @click="handleEdit(row)">
            编辑
          </Button>
          <Popconfirm
            :title="`确认${row.status === 1 ? '禁用' : '启用'}用户吗？`"
            @confirm="handleToggleStatus(row)"
          >
            <Button type="link" size="small">
              {{ row.status === 1 ? '禁用' : '启用' }}
            </Button>
          </Popconfirm>
          <Popconfirm
            title="确认删除用户吗？该操作不可撤销。"
            @confirm="handleDelete(row)"
          >
            <Button type="link" size="small" danger>删除</Button>
          </Popconfirm>
        </Space>
      </template>
    </BasicTable>
    <UserDrawer @reload="tableApi.query()" />
  </Page>
</template>
```

**Step 4: Commit**

```bash
git add frontend/apps/web-antd/src/views/user/
git commit -m "feat: create user management page with VXE Table"
```

---

## Task 11: Update Makefile and Install Dependencies

**Files:**
- Modify: `Makefile`
- Run: `pnpm install`

**Step 1: Update Makefile to use pnpm**

Change the frontend startup command from `npx vite` to `pnpm dev`:

In the `dev` target, change:
```makefile
@cd $(FRONTEND_DIR) && npx vite --port $(FRONTEND_PORT) --strictPort >> /tmp/frontend.log 2>&1 & echo $$! > $(FRONTEND_PID)
```
To:
```makefile
@cd $(FRONTEND_DIR) && pnpm dev >> /tmp/frontend.log 2>&1 & echo $$! > $(FRONTEND_PID)
```

Also update `FRONTEND_PORT` from `3002` to match VITE_PORT in .env.development (3002).

**Step 2: Install pnpm dependencies**

```bash
cd frontend && pnpm install
```

**Step 3: Verify dev server starts**

```bash
cd frontend && pnpm dev
# Should start Vite on port 3002
```

**Step 4: Commit**

```bash
git add Makefile frontend/pnpm-lock.yaml
git commit -m "chore: update Makefile for pnpm and install dependencies"
```

---

## Task 12: Fix TypeScript Errors and Verify

**Step 1: Run type check**

```bash
cd frontend && pnpm typecheck
```

Fix any TypeScript errors that arise from the migration.

**Step 2: Build test**

```bash
cd frontend && pnpm build:antd
```

**Step 3: Manual verification**

Start both frontend and backend:
```bash
make dev
```

Verify:
1. Login page renders and login works
2. Notebook list page shows and CRUD operations work
3. Spec management page renders and CRUD works (admin only)
4. User management page renders and CRUD works (admin only)
5. Layout sidebar, header, and tab bar render correctly
6. Logout works
7. Non-admin users don't see admin menu items

**Step 4: Remove backup**

```bash
rm -rf frontend.bak
```

**Step 5: Final commit**

```bash
git add -A
git commit -m "chore: complete Vben5 UI migration, remove old frontend backup"
```

---

## Summary

| Task | Description | Key Files |
|------|-------------|-----------|
| 1 | Copy Vben5 framework, strip ruoyi pages | `frontend/` (entire directory) |
| 2 | Configure env and vite proxy | `.env`, `.env.development`, `vite.config.mts` |
| 3 | Adapt API request client | `api/request.ts`, `api/helper.ts`, `api/common.ts` |
| 4 | Create API service files | `api/notebook/`, `api/spec/`, `api/user/`, `api/image/` |
| 5 | Adapt auth store | `store/auth.ts`, `store/index.ts` |
| 6 | Configure routes and menus | `router/access.ts`, `routes/modules/platform.ts`, `preferences.ts` |
| 7 | Simplify layout | `layouts/basic.vue` |
| 8 | Notebook list page | `views/notebook/` (3 files) |
| 9 | Spec management page | `views/spec/` (3 files) |
| 10 | User management page | `views/user/` (3 files) |
| 11 | Update Makefile + install | `Makefile`, `pnpm-lock.yaml` |
| 12 | Fix errors + verify | Various |
