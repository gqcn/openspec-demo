import http from './http'

export interface User {
  id: number
  username: string
  uid: number
  isAdmin: number
  status: number
  createdAt: string
}

export interface CreateUserReq {
  username: string
  password: string
  isAdmin: number
}

export async function listUsers(page = 1, size = 20): Promise<{ code: number; data: User[]; total: number }> {
  const res: any = await http.get('/user', { params: { page, size } })
  return { code: res.code, data: res.data?.list || [], total: res.data?.total || 0 }
}

export function createUser(data: CreateUserReq) {
  return http.post<any, { code: number; data: { id: number; uid: number } }>('/user', data)
}

export function updateUserStatus(id: number, status: number) {
  return http.put<any, { code: number }>(`/user/${id}/status`, { status })
}

export function updateUser(id: number, data: { isAdmin?: number; password?: string }) {
  return http.put<any, { code: number }>(`/user/${id}`, data)
}

export function deleteUser(id: number) {
  return http.delete<any, { code: number }>(`/user/${id}`)
}
