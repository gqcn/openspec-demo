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
  uid: number
  isAdmin: number
}

export function listUsers() {
  return http.get<any, { code: number; data: User[] }>('/user/list')
}

export function createUser(data: CreateUserReq) {
  return http.post<any, { code: number; data: User }>('/user/create', data)
}

export function updateUserStatus(id: number, status: number) {
  return http.put<any, { code: number }>('/user/update-status', { id, status })
}
