<script setup lang="ts">
import { computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { logout as apiLogout } from '@/api/auth'
import { ElMessage } from 'element-plus'
import {
  Monitor,
  Setting,
  User,
} from '@element-plus/icons-vue'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()

const username = computed(() => auth.userInfo?.username || '')
const isAdmin = computed(() => auth.isAdmin)

const activeMenu = computed(() => route.path)

async function handleLogout() {
  try {
    await apiLogout()
  } catch {}
  auth.logout()
  router.push('/login')
  ElMessage.success('已退出登录')
}
</script>

<template>
  <el-container style="height: 100vh">
    <el-aside width="220px" style="background: #001529; overflow: hidden">
      <div style="height: 60px; display: flex; align-items: center; justify-content: center; color: #fff; font-size: 18px; font-weight: bold; border-bottom: 1px solid rgba(255,255,255,0.1)">
        AI 训练平台
      </div>
      <el-menu
        :default-active="activeMenu"
        background-color="#001529"
        text-color="#ccc"
        active-text-color="#409eff"
        router
        style="border-right: none"
      >
        <el-menu-item index="/notebooks">
          <el-icon><Monitor /></el-icon>
          <span>我的开发机</span>
        </el-menu-item>
        <template v-if="isAdmin">
          <el-menu-item index="/specs">
            <el-icon><Setting /></el-icon>
            <span>规格管理</span>
          </el-menu-item>
          <el-menu-item index="/users">
            <el-icon><User /></el-icon>
            <span>用户管理</span>
          </el-menu-item>
        </template>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header style="background: #fff; border-bottom: 1px solid #e8e8e8; display: flex; align-items: center; justify-content: flex-end; padding: 0 24px">
        <el-dropdown @command="handleLogout">
          <span style="cursor: pointer; display: flex; align-items: center; gap: 8px">
            <el-avatar size="small" :icon="User" />
            {{ username }}
            <el-icon style="font-size: 12px"><arrow-down /></el-icon>
          </span>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="logout">退出登录</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </el-header>

      <el-main style="background: #f5f5f5; padding: 24px">
        <RouterView />
      </el-main>
    </el-container>
  </el-container>
</template>
