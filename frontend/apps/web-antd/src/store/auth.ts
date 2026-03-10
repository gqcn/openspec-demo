import type { LoginAndRegisterParams } from '@vben/common-ui';
import type { UserInfo } from '@vben/types';

import { ref } from 'vue';
import { useRouter } from 'vue-router';

import { LOGIN_PATH } from '@vben/constants';
import { preferences } from '@vben/preferences';
import { resetAllStores, useAccessStore, useUserStore } from '@vben/stores';

import { notification } from 'ant-design-vue';
import { defineStore } from 'pinia';

import { doLogout, getUserInfoApi, loginApi } from '#/api';
import { transformUserInfo } from '#/api/core/user';
import { $t } from '#/locales';

export const useAuthStore = defineStore('auth', () => {
  const accessStore = useAccessStore();
  const userStore = useUserStore();
  const router = useRouter();

  const loginLoading = ref(false);

  /**
   * Login handler
   */
  async function authLogin(
    params: LoginAndRegisterParams,
    onSuccess?: () => Promise<void> | void,
  ) {
    let userInfo: null | UserInfo = null;
    try {
      loginLoading.value = true;

      // Call GoFrame login API
      const loginResult = await loginApi({
        username: params.username,
        password: params.password,
      });

      // Store token
      accessStore.setAccessToken(loginResult.token);

      // Store user info in localStorage for later retrieval
      localStorage.setItem('ai-platform-user', JSON.stringify(loginResult));

      // Transform and store user info
      userInfo = transformUserInfo(loginResult);
      userStore.setUserInfo(userInfo);

      // Set permissions
      const permissions = loginResult.isAdmin
        ? ['*:*:*', 'spec:manage', 'user:manage']
        : [];
      accessStore.setAccessCodes(permissions);

      if (accessStore.loginExpired) {
        accessStore.setLoginExpired(false);
      } else {
        onSuccess
          ? await onSuccess?.()
          : await router.push(preferences.app.defaultHomePath);
      }

      if (userInfo?.realName) {
        notification.success({
          description: `${$t('authentication.loginSuccessDesc')}:${userInfo?.realName}`,
          duration: 3,
          message: $t('authentication.loginSuccess'),
        });
      }
    } finally {
      loginLoading.value = false;
    }

    return {
      userInfo,
    };
  }

  /**
   * Logout handler
   */
  async function logout(redirect: boolean = true) {
    try {
      await doLogout();
    } catch (error) {
      console.error(error);
    } finally {
      resetAllStores();
      accessStore.setLoginExpired(false);

      await router.replace({
        path: LOGIN_PATH,
        query: redirect
          ? {
              redirect: encodeURIComponent(router.currentRoute.value.fullPath),
            }
          : {},
      });
    }
  }

  /**
   * Fetch user info from localStorage
   */
  async function fetchUserInfo() {
    const result = await getUserInfoApi();
    if (!result) {
      throw new Error('Failed to get user info.');
    }
    const { permissions = [], roles = [], user } = result;

    const userInfo: UserInfo = transformUserInfo(user);
    userInfo.permissions = permissions;
    userInfo.roles = roles;

    userStore.setUserInfo(userInfo);
    accessStore.setAccessCodes(permissions);
    return userInfo;
  }

  function $reset() {
    loginLoading.value = false;
  }

  return {
    $reset,
    authLogin,
    fetchUserInfo,
    loginLoading,
    logout,
  };
});
