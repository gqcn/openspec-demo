import { requestClient } from '#/api/request';

export interface Instance {
  id: number;
  username: string;
  specId: number;
  specName: string;
  imageKey: string;
  imageName: string;
  image: string;
  status: string;
  token: string;
  podIp: string;
  nodeName: string;
  accessUrl: string;
  lastActiveAt: string | null;
  createdAt: string;
}

export interface CreateNotebookReq {
  specId: number;
  imageKey: string;
}

/**
 * Get notebook list
 */
export async function notebookList() {
  const res = await requestClient.get<{ list: Instance[] }>('/notebook');
  const list = (res?.list || []).map((item: any) => ({
    ...item,
    image: item.imageName || item.imageKey,
  }));
  return list;
}

/**
 * Create notebook
 */
export function notebookCreate(data: CreateNotebookReq) {
  return requestClient.post<Instance>('/notebook', data);
}

/**
 * Delete notebook
 */
export function notebookDelete(id: number) {
  return requestClient.delete(`/notebook/${id}`);
}

/**
 * Restart notebook
 */
export function notebookRestart(id: number) {
  return requestClient.post(`/notebook/${id}/restart`);
}
