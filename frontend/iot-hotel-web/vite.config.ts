import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
      '@components': resolve(__dirname, 'src/components'),
      '@views': resolve(__dirname, 'src/views'),
      '@stores': resolve(__dirname, 'src/stores'),
      '@api': resolve(__dirname, 'src/api'),
      '@utils': resolve(__dirname, 'src/utils'),
      '@types': resolve(__dirname, 'src/types'),
      '@assets': resolve(__dirname, 'src/assets')
    }
  },
server: {
  port: 5173,
  host: '0.0.0.0',  // 改为监听所有地址
  proxy: {
    '/api': {
      target: 'http://192.168.1.100:9000',
      changeOrigin: true
    },
    '/uploads': {
      target: 'http://192.168.1.100:9000',
      changeOrigin: true
    },
    '/socket.io': {
      target: 'http://192.168.1.100:9000',
      ws: true,
      changeOrigin: true
    }
  }
},
  css: {
    preprocessorOptions: {
      less: {
        javascriptEnabled: true,
        modifyVars: {
          'primary-color': '#1890ff',
          'link-color': '#1890ff',
          'border-radius-base': '4px'
        }
      }
    }
  }
})
