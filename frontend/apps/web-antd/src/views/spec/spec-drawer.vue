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
      if (isUpdate.value) {
        await specUpdate({ id: recordData.value!.id, ...values });
        message.success('更新成功');
      } else {
        await specCreate(values);
        message.success('创建成功');
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
        formApi.setValues(data);
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
