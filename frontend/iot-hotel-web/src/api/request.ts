import axios from 'axios'
import type { ApiResponse } from '@/types'
import { message } from 'ant-design-vue'

const request = axios.create({
  baseURL: '/api/v1',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json'
  }
})

request.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('auth_token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => Promise.reject(error)
)

request.interceptors.response.use(
  (response) => {
    const res = response.data as ApiResponse
    if (res.code !== undefined && res.code !== 200 && res.code !== 0) {
      message.error(res.message || '请求失败')
      return Promise.reject(new Error(res.message))
    }
    return response.data
  },
  (error) => {
    if (error.response) {
      const status = error.response.status
      switch (status) {
        case 401:
          message.error('未授权，请重新登录')
          localStorage.removeItem('auth_token')
          window.location.href = '/login'
          break
        case 403:
          message.error('拒绝访问')
          break
        case 404:
          message.error('请求的资源不存在')
          break
        case 500:
          message.error('服务器内部错误')
          break
        default:
          message.error(error.response?.data?.message || `请求失败(${status})`)
      }
    } else if (error.code === 'ECONNABORTED') {
      message.error('请求超时，请稍后重试')
    } else {
      message.error('网络错误，请检查网络连接')
    }
    return Promise.reject(error)
  }
)

export default request