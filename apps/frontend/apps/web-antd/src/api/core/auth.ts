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
 * Login API - uses baseRequestClient (no auth header needed)
 */
export async function loginApi(data: AuthApi.LoginParams) {
  return baseRequestClient.post<AuthApi.LoginResult>('/auth/login', data);
}

/**
 * Get user info from localStorage
 */
export async function getUserInfoApi() {
  const stored = localStorage.getItem('ai-platform-user');
  if (!stored) {
    return null;
  }
  const user = JSON.parse(stored);
  const roles: string[] = user.isAdmin ? ['admin'] : ['user'];
  const permissions: string[] = user.isAdmin
    ? ['*:*:*', 'spec:manage', 'user:manage']
    : [];
  return { user, roles, permissions };
}

/**
 * Logout
 */
export async function doLogout() {
  try {
    await requestClient.post('/auth/logout');
  } finally {
    localStorage.removeItem('ai-platform-user');
  }
}

/**
 * Get all menus - not used (frontend routing mode)
 */
export async function getAllMenusApi() {
  return [];
}
