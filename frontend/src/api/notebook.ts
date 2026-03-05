import http from './http'

export interface Instance {
  id: number
  userId: number
  username: string
  specId: number
  specName: string
  image: string
  status: string
  token: string
  podIp: string
  nodeName: string
  idleSince: string | null
  createdAt: string
  stoppedAt: string | null
}

export interface CreateNotebookReq {
  specId: number
  image: string
}

export function listNotebooks() {
  return http.get<any, { code: number; data: Instance[] }>('/notebook/list')
}

export function getNotebook(id: number) {
  return http.get<any, { code: number; data: Instance }>(`/notebook/detail/${id}`)
}

export function createNotebook(data: CreateNotebookReq) {
  return http.post<any, { code: number; data: Instance }>('/notebook/create', data)
}

export function deleteNotebook(id: number) {
  return http.delete<any, { code: number }>(`/notebook/delete/${id}`)
}

export function restartNotebook(id: number) {
  return http.post<any, { code: number }>(`/notebook/restart/${id}`)
}
