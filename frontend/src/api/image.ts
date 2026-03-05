import http from './http'

export interface ImageItem {
  name: string
  tag: string
  fullName: string
  description: string
}

export function listImages() {
  return http.get<any, { code: number; data: ImageItem[] }>('/image/list')
}
