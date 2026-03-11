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

/**
 * Get user list with pagination
 */
export async function userList(page = 1, size = 20) {
  const res = await requestClient.get<{ list: User[]; total: number }>(
    '/user',
    { params: { page, size } },
  );
  return { list: res?.list || [], total: res?.total || 0 };
}

/**
 * Create user
 */
export function userCreate(data: CreateUserReq) {
  return requestClient.post('/user', data);
}

/**
 * Update user
 */
export function userUpdate(id: number, data: { isAdmin?: number; password?: string }) {
  return requestClient.put(`/user/${id}`, data);
}

/**
 * Change user status
 */
export function userStatusChange(id: number, status: number) {
  return requestClient.put(`/user/${id}/status`, { status });
}

/**
 * Delete user
 */
export function userDelete(id: number) {
  return requestClient.delete(`/user/${id}`);
}
