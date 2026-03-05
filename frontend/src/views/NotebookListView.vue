<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { listNotebooks, deleteNotebook, restartNotebook, type Instance } from '@/api/notebook'
import { useAuthStore } from '@/stores/auth'
import CreateNotebookDialog from '@/components/CreateNotebookDialog.vue'
import { ElMessage, ElMessageBox } from 'element-plus'

const auth = useAuthStore()
const isAdmin = computed(() => auth.isAdmin)

const notebooks = ref<Instance[]>([])
const loading = ref(false)
const showCreate = ref(false)

let pollTimer: ReturnType<typeof setInterval> | null = null

const statusMap: Record<string, { label: string; type: string }> = {
  creating: { label: '创建中', type: 'primary' },
  running:  { label: '运行中', type: 'success' },
  stopping: { label: '停止中', type: 'warning' },
  stopped:  { label: '已停止', type: 'info' },
  failed:   { label: '异常',   type: 'danger' },
}

async function fetchList() {
  loading.value = true
  try {
    const res = await listNotebooks()
    notebooks.value = res.data || []
  } finally {
    loading.value = false
  }
}

function needsPolling(list: Instance[]) {
  return list.some((n) => n.status === 'creating' || n.status === 'stopping')
}

function startPoll() {
  if (pollTimer) return
  pollTimer = setInterval(async () => {
    const res = await listNotebooks()
    notebooks.value = res.data || []
    if (!needsPolling(notebooks.value)) stopPoll()
  }, 5000)
}

function stopPoll() {
  if (pollTimer) { clearInterval(pollTimer); pollTimer = null }
}

function watchPolling() {
  if (needsPolling(notebooks.value)) startPoll()
  else stopPoll()
}

async function handleOpen(nb: Instance) {
  // Include token as query param for auto-authentication
  const url = `/jupyter/${nb.token}/lab?token=${nb.token}`
  window.open(url, '_blank')
}

async function handleRestart(nb: Instance) {
  await ElMessageBox.confirm(`确认重启开发机 "${nb.username}" 吗？`, '重启确认', {
    type: 'warning',
    confirmButtonText: '重启',
  })
  try {
    await restartNotebook(nb.id)
    ElMessage.success('已发起重启')
    await fetchList()
    watchPolling()
  } catch (e: any) {
    ElMessage.error(e?.message || '操作失败')
  }
}

async function handleDelete(nb: Instance) {
  await ElMessageBox.confirm(`确认停止并删除开发机 "${nb.username}" 吗？`, '删除确认', {
    type: 'error',
    confirmButtonText: '删除',
  })
  try {
    await deleteNotebook(nb.id)
    ElMessage.success('已删除')
    await fetchList()
    watchPolling()
  } catch (e: any) {
    ElMessage.error(e?.message || '操作失败')
  }
}

async function onCreated() {
  await fetchList()
  startPoll()
}

onMounted(async () => {
  await fetchList()
  watchPolling()
})

onUnmounted(() => stopPoll())
</script>

<template>
  <div>
    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px">
      <h2 style="margin: 0; font-size: 20px; color: #303133">我的开发机</h2>
      <el-button type="primary" :icon="'Plus'" @click="showCreate = true">创建开发机</el-button>
    </div>

    <el-table :data="notebooks" v-loading="loading" border stripe>
      <el-table-column label="ID" prop="id" width="60" />
      <el-table-column v-if="isAdmin" label="用户名" prop="username" width="120" />
      <el-table-column label="规格" prop="specName" width="160" />
      <el-table-column label="镜像" prop="image" min-width="200" show-overflow-tooltip />
      <el-table-column label="状态" width="100">
        <template #default="{ row }">
          <el-tag :type="statusMap[row.status]?.type || 'info'" effect="light">
            {{ statusMap[row.status]?.label || row.status }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="节点" prop="nodeName" width="120" show-overflow-tooltip />
      <el-table-column label="IP" prop="podIp" width="130" />
      <el-table-column label="创建时间" prop="createdAt" width="180" />
      <el-table-column label="操作" width="220" fixed="right">
        <template #default="{ row }">
          <el-button
            v-if="row.status === 'running'"
            type="primary"
            size="small"
            link
            @click="handleOpen(row)"
          >
            进入
          </el-button>
          <el-button
            v-if="row.status === 'running'"
            type="warning"
            size="small"
            link
            @click="handleRestart(row)"
          >
            重启
          </el-button>
          <el-button
            v-if="row.status !== 'stopped' && row.status !== 'stopping'"
            type="danger"
            size="small"
            link
            @click="handleDelete(row)"
          >
            停止
          </el-button>
        </template>
      </el-table-column>
    </el-table>

    <CreateNotebookDialog
      v-model:visible="showCreate"
      @created="onCreated"
    />
  </div>
</template>
