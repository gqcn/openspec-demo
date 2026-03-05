import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

interface UserInfo {
  id: number
  username: string
  isAdmin: number
  uid: number
}

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string>(localStorage.getItem('token') || '')
  const userInfo = ref<UserInfo | null>(
    localStorage.getItem('userInfo') ? JSON.parse(localStorage.getItem('userInfo')!) : null
  )

  const isLoggedIn = computed(() => !!token.value)
  const isAdmin = computed(() => userInfo.value?.isAdmin === 1)

  function setAuth(t: string, info: UserInfo) {
    token.value = t
    userInfo.value = info
    localStorage.setItem('token', t)
    localStorage.setItem('userInfo', JSON.stringify(info))
  }

  function logout() {
    token.value = ''
    userInfo.value = null
    localStorage.removeItem('token')
    localStorage.removeItem('userInfo')
  }

  return { token, userInfo, isLoggedIn, isAdmin, setAuth, logout }
})
