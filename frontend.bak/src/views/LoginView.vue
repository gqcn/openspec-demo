<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { login } from '@/api/auth'
import { ElMessage } from 'element-plus'

const router = useRouter()
const auth = useAuthStore()

const loading = ref(false)
const form = reactive({ username: '', password: '' })
const formRef = ref()

const rules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
}

async function handleLogin() {
  await formRef.value.validate()
  loading.value = true
  try {
    const res = await login({ username: form.username, password: form.password })
    const d = res.data
    auth.setAuth(d.token, {
      id: d.userId,
      username: d.username,
      isAdmin: d.isAdmin,
      uid: d.uid,
    })
    ElMessage.success('登录成功')
    router.push('/notebooks')
  } catch (e: any) {
    ElMessage.error(e?.message || '登录失败')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div style="min-height: 100vh; display: flex; align-items: center; justify-content: center; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)">
    <el-card style="width: 400px; border-radius: 12px">
      <template #header>
        <div style="text-align: center; padding: 8px 0">
          <h2 style="margin: 0; font-size: 24px; color: #303133">AI 训练平台</h2>
          <p style="margin: 8px 0 0; color: #909399; font-size: 14px">欢迎回来，请登录</p>
        </div>
      </template>

      <el-form ref="formRef" :model="form" :rules="rules" label-position="top" size="large">
        <el-form-item label="用户名" prop="username">
          <el-input v-model="form.username" prefix-icon="User" placeholder="请输入用户名" @keyup.enter="handleLogin" />
        </el-form-item>
        <el-form-item label="密码" prop="password">
          <el-input v-model="form.password" type="password" prefix-icon="Lock" placeholder="请输入密码" show-password @keyup.enter="handleLogin" />
        </el-form-item>
        <el-form-item style="margin-top: 8px">
          <el-button type="primary" style="width: 100%" :loading="loading" @click="handleLogin">
            登 录
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>
