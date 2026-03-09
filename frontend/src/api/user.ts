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

export async function listUsers(): Promise<{ code: number; data: User[] }> {
  const res: any = await http.get('/user')
  return { code: res.code, data: res.data?.list || [] }
}

export function createUser(data: CreateUserReq) {
  return http.post<any, { code: number; data: { id: number; uid: number } }>('/user', data)
}

export function updateUserStatus(id: number, status: number) {
  return http.put<any, { code: number }>(`/user/${id}/status`, { status })
}
