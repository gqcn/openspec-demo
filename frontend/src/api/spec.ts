import http from './http'

export interface Spec {
  id: number
  name: string
  description: string
  cpu: string
  memory: string
  gpu: number
  gpuType: string
  enabled: number
  sortOrder: number
  createdAt: string
}

export interface CreateSpecReq {
  name: string
  cpu: string
  memory: string
  gpu: number
  gpuType: string
}

export interface UpdateSpecReq {
  id: number
  name?: string
  cpu?: string
  memory?: string
  gpu?: number
  gpuType?: string
  enabled?: number
}

export async function listSpecs(): Promise<{ code: number; data: Spec[] }> {
  const res: any = await http.get('/spec')
  return { code: res.code, data: res.data?.list || [] }
}

export function createSpec(data: CreateSpecReq) {
  return http.post<any, { code: number; data: Spec }>('/spec', data)
}

export function updateSpec(data: UpdateSpecReq) {
  const { id, ...rest } = data
  return http.put<any, { code: number }>(`/spec/${id}`, rest)
}

export function deleteSpec(id: number) {
  return http.delete<any, { code: number }>(`/spec/${id}`)
}
