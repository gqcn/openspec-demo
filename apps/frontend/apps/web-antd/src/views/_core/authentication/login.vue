<script lang="ts" setup>
import type { LoginAndRegisterParams, VbenFormSchema } from '@vben/common-ui';

import { computed, markRaw } from 'vue';

import { AuthenticationLogin, z } from '@vben/common-ui';
import { $t } from '@vben/locales';

import { Input } from 'ant-design-vue';

import { useAuthStore } from '#/store';

defineOptions({ name: 'Login' });

const authStore = useAuthStore();

const formSchema = computed((): VbenFormSchema[] => {
  return [
    {
      component: markRaw(Input),
      modelPropName: 'value',
      componentProps: {
        size: 'large',
        placeholder: $t('authentication.usernameTip'),
        allowClear: true,
      },
      defaultValue: 'admin',
      fieldName: 'username',
      label: $t('authentication.username'),
      rules: z.string().min(1, { message: $t('authentication.usernameTip') }),
    },
    {
      component: markRaw(Input.Password),
      modelPropName: 'value',
      componentProps: {
        size: 'large',
        placeholder: $t('authentication.passwordTip'),
      },
      defaultValue: 'Admin@123456',
      fieldName: 'password',
      label: $t('authentication.password'),
      rules: z.string().min(5, { message: $t('authentication.passwordTip') }),
    },
  ];
});

async function handleAccountLogin(values: LoginAndRegisterParams) {
  try {
    await authStore.authLogin(values);
  } catch (error) {
    console.error(error);
  }
}
</script>

<template>
  <AuthenticationLogin
    :form-schema="formSchema"
    :loading="authStore.loginLoading"
    :show-code-login="false"
    :show-forget-password="false"
    :show-qrcode-login="false"
    :show-register="false"
    :show-third-party-login="false"
    @submit="handleAccountLogin"
  />
</template>
