import axios from 'axios'
import { useAuthStore } from '@/stores/auth'
import router from '@/router'

const http = axios.create({
  baseURL: '/api',
  timeout: 15000,
})

http.interceptors.request.use((config) => {
  const auth = useAuthStore()
  if (auth.token) {
    config.headers.Authorization = `Bearer ${auth.token}`
  }
  return config
})

http.interceptors.response.use(
  (response) => {
    // GoFrame returns errors as HTTP 200 with non-zero code field.
    // Reject so callers can catch(e) with e.message populated.
    if (response.data?.code !== undefined && response.data.code !== 0) {
      // GoFrame Auth middleware returns {code: 401} for expired/invalid tokens.
      if (response.data.code === 401) {
        const auth = useAuthStore()
        auth.logout()
        router.push('/login')
      }
      return Promise.reject(response.data)
    }
    return response.data
  },
  (error) => {
    if (error.response?.status === 401) {
      const auth = useAuthStore()
      auth.logout()
      router.push('/login')
    }
    return Promise.reject(error.response?.data || error)
  }
)

export default http
