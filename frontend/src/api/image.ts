import http from './http'

export interface ImageItem {
  key: string
  name: string
  image: string
  description: string
}

export async function listImages(): Promise<{ code: number; data: ImageItem[] }> {
  const res: any = await http.get('/image')
  return { code: res.code, data: res.data?.list || [] }
}
