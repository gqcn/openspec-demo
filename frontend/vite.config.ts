import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 3002,
    strictPort: true,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
      // Proxy JupyterLab requests to the Nginx ingress via kind extraPortMappings (port 80)
      '/jupyter': {
        target: 'http://platform.internal:80',
        changeOrigin: true,
        ws: true,
      },
    },
  },
})
