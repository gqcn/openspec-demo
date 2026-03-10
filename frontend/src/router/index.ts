import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

/** Decode JWT payload and check whether the token has expired. */
function isTokenExpired(token: string): boolean {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return true
    const payload = JSON.parse(atob(parts[1]))
    if (!payload.exp) return true
    return payload.exp * 1000 < Date.now()
  } catch {
    return true
  }
}

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'Login',
      component: () => import('@/views/LoginView.vue'),
      meta: { public: true, title: '登录' },
    },
    {
      path: '/',
      component: () => import('@/layouts/MainLayout.vue'),
      children: [
        {
          path: '',
          redirect: '/notebooks',
        },
        {
          path: 'notebooks',
          name: 'Notebooks',
          component: () => import('@/views/NotebookListView.vue'),
          meta: { title: '我的开发机' },
        },
        {
          path: 'specs',
          name: 'Specs',
          component: () => import('@/views/SpecManageView.vue'),
          meta: { adminOnly: true, title: '规格管理' },
        },
        {
          path: 'users',
          name: 'Users',
          component: () => import('@/views/UserManageView.vue'),
          meta: { adminOnly: true, title: '用户管理' },
        },
      ],
    },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (!to.meta.public && !auth.token) {
    return { name: 'Login' }
  }
  if (!to.meta.public && auth.token && isTokenExpired(auth.token)) {
    auth.logout()
    return { name: 'Login' }
  }
  if (to.meta.adminOnly && !auth.isAdmin) {
    return { name: 'Notebooks' }
  }
  const pageTitle = to.meta.title as string | undefined
  document.title = pageTitle ? `${pageTitle} — AI 训练平台` : 'AI 训练平台'
})

export default router
