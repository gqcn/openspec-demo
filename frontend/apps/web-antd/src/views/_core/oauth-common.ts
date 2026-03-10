import type { Component, CSSProperties } from 'vue';

import { ref } from 'vue';

import { DEFAULT_TENANT_ID } from '@vben/constants';

import { createGlobalState } from '@vueuse/core';

/**
 * @description: oauth登录
 */
export interface ListItem {
  title: string;
  description: string;
  avatar?: Component;
  style?: CSSProperties;
}

/**
 * @description: 绑定账号
 */
export interface BindItem extends ListItem {
  source: string;
  bound?: boolean;
}

/**
 * 这里存储登录页的tenantId
 */
export const useLoginTenantId = createGlobalState(() => {
  const loginTenantId = ref(DEFAULT_TENANT_ID);

  return {
    loginTenantId,
  };
});

/**
 * 绑定授权 (stub - social login not implemented)
 */
export async function handleAuthBinding(_source: string) {
  console.warn('Social login binding is not implemented');
}

/**
 * 账号绑定 list (empty - social login not implemented)
 */
export const accountBindList: BindItem[] = [];
