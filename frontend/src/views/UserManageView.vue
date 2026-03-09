<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue'
import { listUsers, createUser, updateUserStatus, type User } from '@/api/user'
import { ElMessage, ElMessageBox } from 'element-plus'

const users = ref<User[]>([])
const loading = ref(false)
const showDialog = ref(false)
const formRef = ref()

const form = reactive({
  username: '',
  password: '',
  isAdmin: 0,
})

const rules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
}

async function fetchList() {
  loading.value = true
  try {
    const res = await listUsers()
    users.value = res.data || []
  } finally {
    loading.value = false
  }
}

function openCreate() {
  Object.assign(form, { username: '', password: '', isAdmin: 0 })
  showDialog.value = true
}

async function handleSave() {
  await formRef.value.validate()
  try {
    await createUser({ ...form })
    ElMessage.success('用户创建成功')
    showDialog.value = false
    await fetchList()
  } catch (e: any) {
    ElMessage.error(e?.message || '创建失败')
  }
}

async function handleToggleStatus(user: User) {
  const newStatus = user.status === 1 ? 0 : 1
  const label = newStatus === 1 ? '启用' : '禁用'
  await ElMessageBox.confirm(`确认${label}用户 "${user.username}" 吗？`, `${label}确认`, { type: 'warning', confirmButtonText: '确认', cancelButtonText: '取消' })
  try {
    await updateUserStatus(user.id, newStatus)
    ElMessage.success(`已${label}`)
    await fetchList()
  } catch (e: any) {
    ElMessage.error(e?.message || '操作失败')
  }
}

onMounted(fetchList)
</script>

<template>
  <div>
    <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px">
      <h2 style="margin: 0; font-size: 20px; color: #303133">用户管理</h2>
      <el-button type="primary" @click="openCreate">新增用户</el-button>
    </div>

    <el-table :data="users" v-loading="loading" border stripe>
      <el-table-column label="ID" prop="id" width="60" />
      <el-table-column label="用户名" prop="username" width="150" />
      <el-table-column label="UID" prop="uid" width="90" />
      <el-table-column label="角色" width="90">
        <template #default="{ row }">
          <el-tag :type="row.isAdmin === 1 ? 'warning' : 'default'" effect="light">
            {{ row.isAdmin === 1 ? '管理员' : '普通用户' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag :type="row.status === 1 ? 'success' : 'info'" effect="light">
            {{ row.status === 1 ? '正常' : '禁用' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column label="创建时间" prop="createdAt" width="180" />
      <el-table-column label="操作" width="120" fixed="right">
        <template #default="{ row }">
          <el-button
            :type="row.status === 1 ? 'warning' : 'success'"
            size="small"
            link
            @click="handleToggleStatus(row)"
          >
            {{ row.status === 1 ? '禁用' : '启用' }}
          </el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-dialog
      v-model="showDialog"
      title="新增用户"
      width="450px"
      :close-on-click-modal="false"
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-width="80px">
        <el-form-item label="用户名" prop="username">
          <el-input v-model="form.username" placeholder="请输入用户名" />
        </el-form-item>
        <el-form-item label="密码" prop="password">
          <el-input v-model="form.password" type="password" placeholder="请输入密码" show-password />
        </el-form-item>
        <el-form-item label="角色">
          <el-radio-group v-model="form.isAdmin">
            <el-radio :value="0">普通用户</el-radio>
            <el-radio :value="1">管理员</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" @click="handleSave">创建</el-button>
      </template>
    </el-dialog>
  </div>
</template>
