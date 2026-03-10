<script lang="ts" setup>
import { computed, ref } from 'vue';

import { useVbenDrawer } from '@vben/common-ui';

import { message } from 'ant-design-vue';

import { useVbenForm } from '#/adapter/form';
import { specCreate, specUpdate } from '#/api/spec';

import { drawerSchema } from './data';

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
  schema: drawerSchema(),
  showDefaultActions: false,
});

const [Drawer, drawerApi] = useVbenDrawer({
  async onConfirm() {
    const { valid } = await formApi.validate();
    if (!valid) return;

    drawerApi.setState({ confirmLoading: true });
    try {
      const values = await formApi.getValues();
      // memory 从 InputNumber 获取的是数字，转为字符串供后端存储
      if (values.memory !== undefined && values.memory !== null) {
        values.memory = String(values.memory);
      }
      if (isUpdate.value) {
        await specUpdate({ id: recordData.value!.id, ...values });
        message.success('更新成功');
      } else {
        await specCreate(values);
        message.success('创建成功');
      }
      emit('reload');
      drawerApi.close();
    } catch {
      // 错误已由请求拦截器统一提示
    } finally {
      drawerApi.setState({ confirmLoading: false });
    }
  },
  onOpenChange(isOpen: boolean) {
    if (isOpen) {
      const data = drawerApi.getData<Record<string, any>>();
      if (data && data.id) {
        recordData.value = data;
        // 兼容旧数据：memory 可能存储为 "8Gi"，去掉 Gi 后缀转为数字
        const formData = { ...data };
        if (typeof formData.memory === 'string') {
          formData.memory = Number.parseFloat(formData.memory.replace(/Gi$/i, ''));
        }
        formApi.setValues(formData);
      } else {
        recordData.value = null;
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
  <Drawer :title="isUpdate ? '编辑规格' : '新增规格'">
    <Form />
  </Drawer>
</template>
