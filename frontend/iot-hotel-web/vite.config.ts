import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

const isLowMemory = process.env.LOW_MEMORY === 'true'

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
  build: {
    target: 'es2020',
    chunkSizeWarningLimit: isLowMemory ? 2000 : 1000,
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules')) {
            if (id.includes('vue') || id.includes('pinia') || id.includes('vue-router')) {
              return 'vendor-vue'
            }
            if (id.includes('ant-design') || id.includes('@ant-design')) {
              return 'vendor-antd'
            }
            if (id.includes('echarts')) {
              return 'vendor-echarts'
            }
            if (id.includes('axios') || id.includes('dayjs') || id.includes('socket.io')) {
              return 'vendor-utils'
            }
          }
        }
      }
    },
    reportCompressedSize: false,
    cssCodeSplit: !isLowMemory,
    ...(isLowMemory ? { minify: false } : {})
  },
server: {
  port: 5173,
  host: '0.0.0.0',  // 改为监听所有地址
  proxy: {
    '/api': {
      target: 'http://localhost:3000',
      changeOrigin: true
    },
    '/uploads': {
      target: 'http://localhost:3000',
      changeOrigin: true
    },
    '/socket.io': {
      target: 'http://localhost:3000',
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
