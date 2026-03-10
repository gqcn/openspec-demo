/**
 * API Request Client for GoFrame backend
 * Response format: {code: 0, data: {...}, message: "..."}
 */

import type { HttpResponse } from '@vben/request';

import { $t } from '@vben/locales';
import { preferences } from '@vben/preferences';
import {
  authenticateResponseInterceptor,
  errorMessageResponseInterceptor,
  RequestClient,
} from '@vben/request';
import { useAccessStore } from '@vben/stores';
import { useAppConfig } from '@vben/hooks';

import { message, Modal } from 'ant-design-vue';

import { useAuthStore } from '#/store';

const { apiURL } = useAppConfig(import.meta.env, import.meta.env.PROD);

/** GoFrame success code */
const GOFRAME_SUCCESS_CODE = 0;
/** HTTP 401 */
const UNAUTHORIZED_CODE = 401;

function createRequestClient(baseURL: string) {
  const client = new RequestClient({
    baseURL,
    errorMessageMode: 'message',
    isReturnNativeResponse: false,
    isTransformResponse: true,
  });

  /**
   * Re-authenticate logic
   */
  async function doReAuthenticate() {
    console.warn('Access token is invalid or expired.');
    const accessStore = useAccessStore();
    const authStore = useAuthStore();
    accessStore.setAccessToken(null);
    if (
      preferences.app.loginExpiredMode === 'modal' &&
      accessStore.isAccessChecked
    ) {
      accessStore.setLoginExpired(true);
    } else {
      await authStore.logout();
    }
  }

  /**
   * Refresh token logic (not used)
   */
  async function doRefreshToken() {
    return '';
  }

  function formatToken(token: null | string) {
    return token ? `Bearer ${token}` : null;
  }

  // Request interceptor: add token
  client.addRequestInterceptor({
    fulfilled: (config) => {
      const accessStore = useAccessStore();
      config.headers.Authorization = formatToken(accessStore.accessToken);
      const language = preferences.app.locale.replace('-', '_');
      config.headers['Accept-Language'] = language;
      return config;
    },
  });

  // Error message interceptor for HTTP errors (must be before response interceptor)
  client.addResponseInterceptor(
    errorMessageResponseInterceptor((msg: string) => message.error(msg)),
  );

  // Response interceptor: handle GoFrame response format
  client.addResponseInterceptor<HttpResponse>({
    fulfilled: async (response) => {
      const { isReturnNativeResponse, isTransformResponse } = response.config;

      if (isReturnNativeResponse) {
        return response;
      }

      if (!isTransformResponse) {
        return response.data;
      }

      const axiosResponseData = response.data;
      if (!axiosResponseData) {
        throw new Error($t('http.apiRequestFailed'));
      }

      const { code, data, message: msg } = axiosResponseData;

      // GoFrame: code 0 = success
      const hasSuccess =
        Reflect.has(axiosResponseData, 'code') &&
        code === GOFRAME_SUCCESS_CODE;

      if (hasSuccess) {
        if (response.config.successMessageMode === 'modal') {
          Modal.success({
            content: msg || $t('http.operationSuccess'),
            title: $t('http.successTip'),
          });
        } else if (response.config.successMessageMode === 'message') {
          message.success(msg || $t('http.operationSuccess'));
        }
        return data;
      }

      // Handle 401
      if (code === UNAUTHORIZED_CODE) {
        const accessStore = useAccessStore();
        const authStore = useAuthStore();
        accessStore.setAccessToken(null);
        await authStore.logout();
        throw new Error($t('http.loginTimeout'));
      }

      // Other errors
      const errorMsg = msg || $t('http.apiRequestFailed');

      if (response.config.errorMessageMode === 'modal') {
        Modal.error({
          content: errorMsg,
          title: $t('http.errorTip'),
        });
      } else if (response.config.errorMessageMode === 'message') {
        message.error(errorMsg);
      }

      throw new Error(errorMsg);
    },
  });

  // Token expiry handling
  client.addResponseInterceptor(
    authenticateResponseInterceptor({
      client,
      doReAuthenticate,
      doRefreshToken,
      enableRefreshToken: preferences.app.enableRefreshToken,
      formatToken,
    }),
  );

  return client;
}

export const requestClient = createRequestClient(apiURL);

export const baseRequestClient = new RequestClient({ baseURL: apiURL });
