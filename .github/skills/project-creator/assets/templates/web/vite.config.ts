import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: {{WEB_PORT}},
    proxy: {
      '/api': {
        target: process.env.VITE_API_URL || 'https://localhost:{{API_HTTPS_PORT}}',
        changeOrigin: true,
        secure: false,
      },
    },
  },
})
