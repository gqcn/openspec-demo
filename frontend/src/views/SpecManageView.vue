<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue'
import { listSpecs, createSpec, updateSpec, deleteSpec, type Spec } from '@/api/spec'
import { ElMessage, ElMessageBox } from 'element-plus'

const specs = ref<Spec[]>([])
const loading = ref(false)
const showDialog = ref(false)
const editingSpec = ref<Spec | null>(null)

const form = reactive({
  name: '',
  cpu: '',
  memory: '',
  gpu: 0,
  gpuType: '',
})

const formRef = ref()
const rules = {
  name: [{ required: true, message: '请输入规格名称', trigger: 'blur' }],
  cpu: [{ required: true, message: '请输入 CPU 配置', trigger: 'blur' }],
  memory: [{ required: true, message: '请输入内存配置', trigger: 'blur' }],
}

async function fetchList() {
  loading.value = true
  try {
    const res = await listSpecs()
    specs.value = res.data || []
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingSpec.value = null
  Object.assign(form, { name: '', cpu: '', memory: '', gpu: 0, gpuType: '' })
  showDialog.value = true
}

function openEdit(spec: Spec) {
  editingSpec.value = spec
  Object.assign(form, {
    name: spec.name,
    cpu: spec.cpu,
    memory: spec.memory,
    gpu: spec.gpu,
    gpuType: spec.gpuType,
  })
  showDialog.value = true
}

async function handleSave() {
  await formRef.value.validate()
  try {
    if (editingSpec.value) {
      await updateSpec({ ...form, id: editingSpec.value.id, status: editingSpec.value.status })
      ElMessage.success('更新成功')
    } else {
      await createSpec({ ...form })
      ElMessage.success('创建成功')
    }
    showDialog.value = false
    await fetchList()
  } catch (e: any) {
    ElMessage.error(e?.message || '操作失败')
  }
}

async function handleToggleStatus(spec: Spec) {
  const newStatus = spec.status === 1 ? 0 : 1
  const label = newStatus === 1 ? '启用' : '禁用'
  await ElMessageBox.confirm(`确认${label}规格 "${spec.name}" 吗？`, `${label}确认`, { type: 'warning' })
  try {
    await updateSpec({ ...spec, status: newStatus })
    ElMessage.success(`已${label}`)
    await fetchList()
  } catch (e: any) {
    ElMessage.error(e?.message || '操作失败')
  }
}

async function handleDelete(spec: Spec) {
  await ElMessageBox.confirm(`确认删除规格 "${spec.name}" 吗？`, '删除确认', { type: 'error' })
  try {
    await deleteSpec(spec.id)
    ElMessage.success('已删除')
    await fetchList()
  } catch (e: any) {
    ElMessage.error(e?.message || '删除失败')
  }
}

onMounted(fetchList)
</script>

<template>
  <div>
    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px">
      <h2 style="margin: 0; font-size: 20px; color: #303133">规格管理</h2>
      <el-button type="primary" @click="openCreate">新增规格</el-button>
    </div>

    <el-table :data="specs" v-loading="loading" border stripe>
      <el-table-column label="ID" prop="id" width="60" />
      <el-table-column label="名称" prop="name" width="160" />
      <el-table-column label="CPU" prop="cpu" width="100" />
      <el-table-column label="内存" prop="memory" width="100" />
      <el-table-column label="GPU 数量" prop="gpu" width="90" />
      <el-table-column label="GPU 型号" prop="gpuType" width="140" />
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 1 ? 'success' : 'info'" effect="light">
            {{ row.status === 1 ? '启用' : '禁用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="创建时间" prop="createdAt" width="180" />
      <el-table-column label="操作" width="200" fixed="right">
        <template #default="{ row }">
          <el-button type="primary" size="small" link @click="openEdit(row)">编辑</el-button>
          <el-button
            :type="row.status === 1 ? 'warning' : 'success'"
            size="small"
            link
            @click="handleToggleStatus(row)"
          >
            {{ row.status === 1 ? '禁用' : '启用' }}
          </el-button>
          <el-button type="danger" size="small" link @click="handleDelete(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog
      v-model="showDialog"
      :title="editingSpec ? '编辑规格' : '新增规格'"
      width="500px"
      :close-on-click-modal="false"
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-width="90px">
        <el-form-item label="名称" prop="name">
          <el-input v-model="form.name" placeholder="如: 4C8G" />
        </el-form-item>
        <el-form-item label="CPU" prop="cpu">
          <el-input v-model="form.cpu" placeholder="如: 4" />
        </el-form-item>
        <el-form-item label="内存" prop="memory">
          <el-input v-model="form.memory" placeholder="如: 8Gi" />
        </el-form-item>
        <el-form-item label="GPU 数量">
          <el-input-number v-model="form.gpu" :min="0" :max="8" />
        </el-form-item>
        <el-form-item label="GPU 型号">
          <el-input v-model="form.gpuType" placeholder="如: nvidia.com/gpu" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>
