import http from './http'

export interface LoginReq {
  username: string
  password: string
}

export interface LoginResp {
  token: string
  userId: number
  username: string
  isAdmin: number
  uid: number
}

export function login(data: LoginReq) {
  return http.post<any, { code: number; data: LoginResp }>('/auth/login', data)
}

export function logout() {
  return http.post('/auth/logout')
}
