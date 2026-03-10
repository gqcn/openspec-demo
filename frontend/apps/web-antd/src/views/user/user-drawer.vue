<script lang="ts" setup>
import { computed, ref } from 'vue';

import { useVbenDrawer } from '@vben/common-ui';

import { message } from 'ant-design-vue';

import { useVbenForm } from '#/adapter/form';
import { userCreate, userUpdate } from '#/api/user';

import { createSchema, editSchema } from './data';

const emit = defineEmits<{ reload: [] }>();

const recordData = ref<Record<string, any> | null>(null);
const isUpdate = computed(() => !!recordData.value);

const [Form, formApi] = useVbenForm({
  commonConfig: {
    componentProps: {
      class: 'w-full',
    },
  },
  layout: 'vertical',
  schema: createSchema(),
  showDefaultActions: false,
});

const [Drawer, drawerApi] = useVbenDrawer({
  async onConfirm() {
    const { valid } = await formApi.validate();
    if (!valid) return;

    drawerApi.setState({ confirmLoading: true });
    try {
      const values = await formApi.getValues();
      if (isUpdate.value) {
        const payload: { isAdmin?: number; password?: string } = {
          isAdmin: values.isAdmin,
        };
        if (values.password) {
          payload.password = values.password;
        }
        await userUpdate(recordData.value!.id, payload);
        message.success('用户信息已更新');
      } else {
        await userCreate(values);
        message.success('用户创建成功');
      }
      emit('reload');
      drawerApi.close();
    } catch (e: any) {
      message.error(e?.message || '操作失败');
    } finally {
      drawerApi.setState({ confirmLoading: false });
    }
  },
  onOpenChange(isOpen: boolean) {
    if (isOpen) {
      const data = drawerApi.getData<Record<string, any>>();
      if (data && data.id) {
        recordData.value = data;
        formApi.setState({ schema: editSchema() });
        // Use nextTick-like delay to ensure schema is applied before setting values
        setTimeout(() => {
          formApi.setValues({ ...data, password: '' });
        }, 0);
      } else {
        recordData.value = null;
        formApi.resetForm();
        formApi.setState({ schema: createSchema() });
      }
    }
  },
  onClosed() {
    formApi.resetForm();
    recordData.value = null;
  },
});
</script>

<template>
  <Drawer :title="isUpdate ? '编辑用户' : '新增用户'">
    <Form />
  </Drawer>
</template>
