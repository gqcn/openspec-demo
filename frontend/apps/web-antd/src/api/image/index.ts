import { requestClient } from '#/api/request';

export interface ImageItem {
  key: string;
  name: string;
  image: string;
  description: string;
}

/**
 * Get image list
 */
export async function imageList() {
  const res = await requestClient.get<{ list: ImageItem[] }>('/image');
  return res?.list || [];
}
