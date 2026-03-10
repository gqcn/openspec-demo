<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';

import { LOGIN_PATH } from '@vben/constants';
import { cn } from '@vben/utils';

import { message, Spin } from 'ant-design-vue';

const router = useRouter();

onMounted(async () => {
  message.warning('Social login is not implemented');
  setTimeout(() => {
    router.push(LOGIN_PATH);
  }, 1500);
});
</script>

<template>
  <div :class="cn('flex items-center justify-center', 'h-screen w-screen')">
    <Spin size="large" />
  </div>
</template>
