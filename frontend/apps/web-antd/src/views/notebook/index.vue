<script lang="ts" setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';

import { Page, useVbenModal } from '@vben/common-ui';
import { useAccessStore } from '@vben/stores';

import {
  Button,
  message,
  Popconfirm,
  Table,
  Tag,
  Tooltip,
} from 'ant-design-vue';

import {
  type Instance,
  notebookDelete,
  notebookList,
  notebookRestart,
} from '#/api/notebook';

import CreateModal from './create-modal.vue';
import { columns as baseColumns, statusMap } from './data';

const accessStore = useAccessStore();
const isAdmin = computed(() =>
  (accessStore.accessCodes as string[]).includes('*:*:*'),
);

const notebooks = ref<Instance[]>([]);
const loading = ref(false);
let pollTimer: null | ReturnType<typeof setInterval> = null;

// Dynamic columns: show username only for admin
const columns = computed(() => {
  if (isAdmin.value) {
    return baseColumns;
  }
  return baseColumns.filter((col) => col.dataIndex !== 'username');
});

// True when the current user already has a creating/running/stopping instance
const hasActiveNotebook = computed(() =>
  notebooks.value.some((n) =>
    ['creating', 'running', 'stopping'].includes(n.status),
  ),
);

function needsPolling(list: Instance[]) {
  return list.some((n) =>
    ['creating', 'running', 'stopping'].includes(n.status),
  );
}

async function fetchList() {
  loading.value = true;
  try {
    notebooks.value = await notebookList();
  } finally {
    loading.value = false;
  }
}

function startPoll() {
  if (pollTimer) return;
  pollTimer = setInterval(async () => {
    notebooks.value = await notebookList();
    if (!needsPolling(notebooks.value)) {
      stopPoll();
    }
  }, 5000);
}

function stopPoll() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

function watchPolling() {
  if (needsPolling(notebooks.value)) {
    startPoll();
  } else {
    stopPoll();
  }
}

function handleOpen(record: Instance) {
  const url = `/jupyter/${record.token}/lab`;
  window.open(url, '_blank');
}

async function handleRestart(record: Instance) {
  try {
    await notebookRestart(record.id);
    message.success('已发起重启');
    await fetchList();
    watchPolling();
  } catch {
    // 错误已由请求拦截器统一提示
  }
}

async function handleStop(record: Instance) {
  try {
    await notebookDelete(record.id);
    message.success('已停止');
    await fetchList();
    watchPolling();
  } catch {
    // 错误已由请求拦截器统一提示
  }
}

async function handlePurge(record: Instance) {
  try {
    await notebookDelete(record.id);
    message.success('记录已删除');
    await fetchList();
  } catch {
    // 错误已由请求拦截器统一提示
  }
}

// Create Modal
const [CreateModalComp, createModalApi] = useVbenModal({
  connectedComponent: CreateModal,
});

function handleCreate() {
  createModalApi.open();
}

async function onReload() {
  await fetchList();
  startPoll();
}

onMounted(async () => {
  await fetchList();
  watchPolling();
});

onUnmounted(() => stopPoll());
</script>

<template>
  <Page auto-content-height>
    <div
      style="
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 16px;
      "
    >
      <h2 style="margin: 0; font-size: 18px">我的开发机</h2>
      <Tooltip
        :title="
          hasActiveNotebook
            ? '您已有运行中的开发机，请先停止后再创建'
            : undefined
        "
      >
        <Button
          :disabled="hasActiveNotebook"
          type="primary"
          @click="handleCreate"
        >
          创建开发机
        </Button>
      </Tooltip>
    </div>

    <Table
      :columns="columns"
      :data-source="notebooks"
      :loading="loading"
      :pagination="false"
      :scroll="{ x: 1200 }"
      bordered
      row-key="id"
      size="middle"
    >
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'status'">
          <Tag :color="statusMap[record.status]?.color || 'default'">
            {{ statusMap[record.status]?.label || record.status }}
          </Tag>
        </template>

        <template v-if="column.key === 'action'">
          <Button
            v-if="record.status === 'running'"
            size="small"
            type="link"
            @click="handleOpen(record)"
          >
            进入
          </Button>

          <Popconfirm
            v-if="record.status === 'running'"
            title="确认重启该开发机吗？"
            @confirm="handleRestart(record)"
          >
            <Button size="small" type="link"> 重启 </Button>
          </Popconfirm>

          <Popconfirm
            v-if="
              record.status !== 'stopped' &&
              record.status !== 'stopping' &&
              record.status !== 'failed'
            "
            title="确认停止该开发机吗？"
            @confirm="handleStop(record)"
          >
            <Button danger size="small" type="link"> 停止 </Button>
          </Popconfirm>

          <Popconfirm
            v-if="
              record.status === 'stopped' || record.status === 'failed'
            "
            title="确认删除该记录吗？此操作不可撤销。"
            @confirm="handlePurge(record)"
          >
            <Button danger size="small" type="link"> 删除记录 </Button>
          </Popconfirm>
        </template>
      </template>
    </Table>

    <CreateModalComp @reload="onReload" />
  </Page>
</template>
