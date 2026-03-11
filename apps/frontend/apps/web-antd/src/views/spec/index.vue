<script lang="ts" setup>
import { Page, useVbenDrawer } from '@vben/common-ui';

import { Button, message, Popconfirm, Tag } from 'ant-design-vue';

import { useVbenVxeGrid } from '#/adapter/vxe-table';
import { type Spec, specDelete, specList, specUpdate } from '#/api/spec';

import { columns } from './data';
import SpecDrawer from './spec-drawer.vue';

const [SpecDrawerComp, specDrawerApi] = useVbenDrawer({
  connectedComponent: SpecDrawer,
});

const [Grid, gridApi] = useVbenVxeGrid({
  gridOptions: {
    columns,
    proxyConfig: {
      ajax: {
        query: async ({ page }) => {
          const result = await specList(page.currentPage, page.pageSize);
          return { rows: result.list, total: result.total };
        },
      },
    },
    toolbarConfig: {
      custom: true,
      refresh: true,
      zoom: true,
      slots: {
        buttons: 'toolbar-buttons',
      },
    },
  },
});

function handleCreate() {
  specDrawerApi.setData(null);
  specDrawerApi.open();
}

function handleEdit(record: Spec) {
  specDrawerApi.setData(record);
  specDrawerApi.open();
}

async function handleToggle(record: Spec) {
  try {
    const newEnabled = record.enabled === 1 ? 0 : 1;
    await specUpdate({ id: record.id, enabled: newEnabled });
    message.success(newEnabled === 1 ? '已启用' : '已禁用');
    gridApi.query();
  } catch {
    // 错误已由请求拦截器统一提示
  }
}

async function handleDelete(record: Spec) {
  try {
    await specDelete(record.id);
    message.success('已删除');
    gridApi.query();
  } catch {
    // 错误已由请求拦截器统一提示
  }
}

function onReload() {
  gridApi.query();
}
</script>

<template>
  <Page auto-content-height>
    <Grid>
      <template #toolbar-buttons>
        <Button type="primary" @click="handleCreate"> 新增规格 </Button>
      </template>

      <template #status="{ row }">
        <Tag :color="row.enabled === 1 ? 'success' : 'default'">
          {{ row.enabled === 1 ? '启用' : '禁用' }}
        </Tag>
      </template>

      <template #action="{ row }">
        <Button size="small" type="link" @click="handleEdit(row)">
          编辑
        </Button>
        <Popconfirm
          :title="`确认${row.enabled === 1 ? '禁用' : '启用'}规格 &quot;${row.name}&quot; 吗？`"
          @confirm="handleToggle(row)"
        >
          <Button size="small" type="link">
            {{ row.enabled === 1 ? '禁用' : '启用' }}
          </Button>
        </Popconfirm>
        <Popconfirm
          :title="`确认删除规格 &quot;${row.name}&quot; 吗？`"
          @confirm="handleDelete(row)"
        >
          <Button danger size="small" type="link"> 删除 </Button>
        </Popconfirm>
      </template>
    </Grid>

    <SpecDrawerComp @reload="onReload" />
  </Page>
</template>
