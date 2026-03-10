import http from './http'

export interface Instance {
  id: number
  username: string
  specId: number
  specName: string
  imageKey: string
  imageName: string
  image: string
  status: string
  token: string
  podIp: string
  nodeName: string
  accessUrl: string
  lastActiveAt: string | null
  createdAt: string
}

export interface CreateNotebookReq {
  specId: number
  imageKey: string
}

export async function listNotebooks(): Promise<{ code: number; data: Instance[] }> {
  const res: any = await http.get('/notebook')
  const list = (res.data?.list || []).map((item: any) => ({
    ...item,
    image: item.imageName || item.imageKey,
  }))
  return { code: res.code, data: list }
}

export function getNotebook(id: number) {
  return http.get<any, { code: number; data: Instance }>(`/notebook/${id}`)
}

export function createNotebook(data: CreateNotebookReq) {
  return http.post<any, { code: number; data: Instance }>('/notebook', data)
}

export function deleteNotebook(id: number) {
  return http.delete<any, { code: number }>(`/notebook/${id}`)
}

export function restartNotebook(id: number) {
  return http.post<any, { code: number }>(`/notebook/${id}/restart`)
}
