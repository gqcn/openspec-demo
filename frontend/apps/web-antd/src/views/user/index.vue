<script lang="ts" setup>
import { Page, useVbenDrawer } from '@vben/common-ui';

import { Button, message, Popconfirm, Tag } from 'ant-design-vue';

import { useVbenVxeGrid } from '#/adapter/vxe-table';
import {
  type User,
  userDelete,
  userList,
  userStatusChange,
} from '#/api/user';

import { columns, querySchema } from './data';
import UserDrawer from './user-drawer.vue';

const [UserDrawerComp, userDrawerApi] = useVbenDrawer({
  connectedComponent: UserDrawer,
});

const [Grid, gridApi] = useVbenVxeGrid({
  formOptions: {
    schema: querySchema(),
  },
  gridOptions: {
    columns,
    proxyConfig: {
      ajax: {
        query: async ({ page, form }) => {
          const result = await userList(page.currentPage, page.pageSize);
          // Client-side username filter if form has username
          let list = result.list;
          if (form?.username) {
            list = list.filter((item: User) =>
              item.username
                .toLowerCase()
                .includes(form.username.toLowerCase()),
            );
          }
          return { rows: list, total: result.total };
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
  userDrawerApi.setData(null);
  userDrawerApi.open();
}

function handleEdit(record: User) {
  userDrawerApi.setData(record);
  userDrawerApi.open();
}

async function handleToggleStatus(record: User) {
  try {
    const newStatus = record.status === 1 ? 0 : 1;
    await userStatusChange(record.id, newStatus);
    message.success(newStatus === 1 ? '已启用' : '已禁用');
    gridApi.query();
  } catch (e: any) {
    message.error(e?.message || '操作失败');
  }
}

async function handleDelete(record: User) {
  try {
    await userDelete(record.id);
    message.success('用户已删除');
    gridApi.query();
  } catch (e: any) {
    message.error(e?.message || '删除失败');
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
        <Button type="primary" @click="handleCreate"> 新增用户 </Button>
      </template>

      <template #role="{ row }">
        <Tag :color="row.isAdmin === 1 ? 'orange' : 'blue'">
          {{ row.isAdmin === 1 ? '管理员' : '普通用户' }}
        </Tag>
      </template>

      <template #status="{ row }">
        <Tag :color="row.status === 1 ? 'success' : 'default'">
          {{ row.status === 1 ? '正常' : '禁用' }}
        </Tag>
      </template>

      <template #action="{ row }">
        <Button size="small" type="link" @click="handleEdit(row)">
          编辑
        </Button>
        <Popconfirm
          :title="`确认${row.status === 1 ? '禁用' : '启用'}用户 &quot;${row.username}&quot; 吗？`"
          @confirm="handleToggleStatus(row)"
        >
          <Button size="small" type="link">
            {{ row.status === 1 ? '禁用' : '启用' }}
          </Button>
        </Popconfirm>
        <Popconfirm
          title="确认删除该用户吗？该操作不可撤销"
          @confirm="handleDelete(row)"
        >
          <Button danger size="small" type="link"> 删除 </Button>
        </Popconfirm>
      </template>
    </Grid>

    <UserDrawerComp @reload="onReload" />
  </Page>
</template>
