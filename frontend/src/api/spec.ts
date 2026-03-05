import http from './http'

export interface Spec {
  id: number
  name: string
  cpu: string
  memory: string
  gpu: number
  gpuType: string
  status: number
  createdAt: string
}

export interface CreateSpecReq {
  name: string
  cpu: string
  memory: string
  gpu: number
  gpuType: string
}

export interface UpdateSpecReq extends CreateSpecReq {
  id: number
  status: number
}

export function listSpecs() {
  return http.get<any, { code: number; data: Spec[] }>('/spec/list')
}

export function createSpec(data: CreateSpecReq) {
  return http.post<any, { code: number; data: Spec }>('/spec/create', data)
}

export function updateSpec(data: UpdateSpecReq) {
  return http.put<any, { code: number }>('/spec/update', data)
}

export function deleteSpec(id: number) {
  return http.delete<any, { code: number }>(`/spec/delete/${id}`)
}
