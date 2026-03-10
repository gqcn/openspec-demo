import { defineConfig } from '@vben/vite-config';

export default defineConfig(async () => {
  return {
    application: {},
    vite: {
      server: {
        allowedHosts: ['localhost'],
        proxy: {
          '/api': {
            changeOrigin: true,
            target: 'http://localhost:8080',
          },
          '/jupyter': {
            changeOrigin: true,
            target: 'http://platform.internal:80',
            ws: true,
          },
        },
      },
    },
  };
}) as any;
