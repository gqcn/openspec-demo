import type { UserInfo } from '@vben/types';

import type { AuthApi } from './auth';

/**
 * Transform backend user data to Vben UserInfo format
 */
export function transformUserInfo(
  userData: AuthApi.LoginResult,
): UserInfo {
  return {
    userId: userData.userId,
    username: userData.username,
    realName: userData.username,
    avatar: '',
    desc: '',
    roles: userData.isAdmin ? ['admin'] : ['user'],
    homePath: '/notebooks',
  };
}
