import { requestClient } from '#/api/request';

export interface Spec {
  id: number;
  name: string;
  description: string;
  cpu: string;
  memory: string;
  gpu: number;
  gpuType: string;
  enabled: number;
  sortOrder: number;
  createdAt: string;
}

export interface CreateSpecReq {
  name: string;
  cpu: string;
  memory: string;
  gpu: number;
  gpuType: string;
}

export interface UpdateSpecReq {
  id: number;
  name?: string;
  cpu?: string;
  memory?: string;
  gpu?: number;
  gpuType?: string;
  enabled?: number;
}

/**
 * Get spec list with pagination
 */
export async function specList(page = 1, size = 20) {
  const res = await requestClient.get<{ list: Spec[]; total: number }>(
    '/spec',
    { params: { page, size } },
  );
  return { list: res?.list || [], total: res?.total || 0 };
}

/**
 * Create spec
 */
export function specCreate(data: CreateSpecReq) {
  return requestClient.post<Spec>('/spec', data);
}

/**
 * Update spec
 */
export function specUpdate(data: UpdateSpecReq) {
  const { id, ...rest } = data;
  return requestClient.put(`/spec/${id}`, rest);
}

/**
 * Delete spec
 */
export function specDelete(id: number) {
  return requestClient.delete(`/spec/${id}`);
}
