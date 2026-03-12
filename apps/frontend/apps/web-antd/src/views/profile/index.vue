<script lang="ts" setup>
import { computed, onMounted, ref } from 'vue';

import { useUserStore } from '@vben/stores';
import { z } from '@vben/common-ui';

import { Avatar, Button, Card, Tabs, message } from 'ant-design-vue';
import { UserOutlined } from '@ant-design/icons-vue';

import { useVbenForm } from '#/adapter/form';
import { getProfile, updateProfile } from '#/api/user';

const userStore = useUserStore();
const loading = ref(false);
const activeTab = ref('basic');

// Profile data from backend
const profileData = ref<{
  id: number;
  username: string;
  email: string;
  isAdmin: number;
  uid: number;
} | null>(null);

// 基本信息表单
const [BasicForm, basicFormApi] = useVbenForm({
  commonConfig: {
    componentProps: {
      class: 'w-full',
    },
  },
  layout: 'vertical',
  schema: [
    {
      component: 'Input',
      fieldName: 'email',
      label: '邮箱',
      componentProps: {
        placeholder: '请输入邮箱',
      },
      rules: z.string().email('请输入有效的邮箱地址').or(z.literal('')),
    },
  ],
  showDefaultActions: false,
});

// 安全设置表单
const [SecurityForm, securityFormApi] = useVbenForm({
  commonConfig: {
    componentProps: {
      class: 'w-full',
    },
  },
  layout: 'vertical',
  schema: [
    {
      component: 'InputPassword',
      fieldName: 'password',
      label: '新密码',
      componentProps: {
        placeholder: '请输入新密码（至少8位）',
      },
      rules: z.string().min(8, '密码至少8位').or(z.literal('')),
    },
    {
      component: 'InputPassword',
      fieldName: 'confirmPassword',
      label: '确认新密码',
      componentProps: {
        placeholder: '请再次输入新密码',
      },
    },
  ],
  showDefaultActions: false,
});

// 用户信息
const username = computed(() => profileData.value?.username || userStore.userInfo?.username || '');
const email = computed(() => profileData.value?.email || '');
const roles = computed(() => {
  const isAdmin = profileData.value?.isAdmin ?? (userStore.userInfo?.roles?.includes('admin') ? 1 : 0);
  return isAdmin === 1 ? ['管理员'] : ['普通用户'];
});

// Fetch profile data from backend
async function fetchProfile() {
  try {
    const data = await getProfile();
    profileData.value = data;
    // Update form default value
    basicFormApi.setValues({ email: data.email || '' });
  } catch (error) {
    console.error('Failed to fetch profile:', error);
  }
}

onMounted(() => {
  fetchProfile();
});

async function handleBasicSubmit() {
  try {
    const values = await basicFormApi.getValues();
    const result = await basicFormApi.validate();

    if (!result.valid) {
      return;
    }

    loading.value = true;
    await updateProfile({ email: values.email });
    message.success('邮箱已更新');
    // Refresh profile data
    await fetchProfile();
  } catch (error) {
    console.error('Submit error:', error);
  } finally {
    loading.value = false;
  }
}

async function handleSecuritySubmit() {
  try {
    const values = await securityFormApi.getValues();
    const result = await securityFormApi.validate();

    if (!result.valid) {
      return;
    }

    if (!values.password) {
      message.warning('请输入新密码');
      return;
    }

    if (values.password !== values.confirmPassword) {
      message.error('两次输入的密码不一致');
      return;
    }

    loading.value = true;
    await updateProfile({ password: values.password });
    message.success('密码已更新');
    securityFormApi.setValues({ password: '', confirmPassword: '' });
  } catch (error) {
    console.error('Submit error:', error);
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="flex gap-6 p-6">
    <!-- 左侧用户信息卡片 -->
    <Card class="w-80 flex-shrink-0" :bordered="false">
      <div class="flex flex-col items-center">
        <!-- 头像 -->
        <Avatar :size="100" class="mb-4">
          <template #icon>
            <UserOutlined />
          </template>
        </Avatar>

        <!-- 用户名 -->
        <div class="text-xl font-semibold mb-6">{{ username }}</div>

        <!-- 用户信息列表 -->
        <div class="w-full space-y-3 text-sm">
          <div class="flex items-center">
            <span class="text-gray-600 w-20">账号：</span>
            <span class="text-gray-900">{{ username }}</span>
          </div>

          <div class="flex items-center">
            <span class="text-gray-600 w-20">邮箱：</span>
            <span class="text-gray-900">{{ email || '未设置' }}</span>
          </div>

          <div v-if="roles.length > 0" class="flex items-start">
            <span class="text-gray-600 w-20">角色：</span>
            <div class="flex flex-wrap gap-2">
              <span
                v-for="role in roles"
                :key="role"
                class="px-2 py-1 bg-blue-50 text-blue-600 rounded text-xs"
              >
                {{ role }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </Card>

    <!-- 右侧设置表单 -->
    <Card class="flex-1" :bordered="false">
      <Tabs v-model:activeKey="activeTab">
        <Tabs.TabPane key="basic" tab="基本设置">
          <div class="max-w-md">
            <BasicForm />
            <Button
              type="primary"
              :loading="loading"
              class="mt-4"
              @click="handleBasicSubmit"
            >
              更新信息
            </Button>
          </div>
        </Tabs.TabPane>

        <Tabs.TabPane key="security" tab="安全设置">
          <div class="max-w-md">
            <SecurityForm />
            <Button
              type="primary"
              :loading="loading"
              class="mt-4"
              @click="handleSecuritySubmit"
            >
              更新密码
            </Button>
          </div>
        </Tabs.TabPane>
      </Tabs>
    </Card>
  </div>
</template>