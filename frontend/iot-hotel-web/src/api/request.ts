import axios from 'axios'
import type { ApiResponse } from '@/types'
import { message } from 'ant-design-vue'

function shouldClearAuth(error: any): boolean {
  const msg = String(error?.response?.data?.message || '').toLowerCase()
  if (!msg) {
    return false
  }
  return (
    msg.includes('认证令牌') ||
    msg.includes('令牌验证失败') ||
    msg.includes('未提供认证令牌') ||
    msg.includes('token') ||
    msg.includes('unauthorized')
  )
}

function getAuthToken(): string {
  const rawToken = localStorage.getItem('auth_token')
  if (rawToken && rawToken !== 'null' && rawToken !== 'undefined') {
    return rawToken
  }
  const rawUserInfo = localStorage.getItem('user_info')
  if (!rawUserInfo) {
    return ''
  }
  try {
    const parsed = JSON.parse(rawUserInfo)
    const fallback = parsed?.token
    if (fallback && fallback !== 'null' && fallback !== 'undefined') {
      localStorage.setItem('auth_token', fallback)
      return fallback
    }
  } catch (_) {
    return ''
  }
  return ''
}

const request = axios.create({
  baseURL: '/api/v1',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json'
  }
})

request.interceptors.request.use(
  (config) => {
    const token = getAuthToken()
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
    const code = Number(res.code)
    const isBusinessSuccess =
      res.code === undefined ||
      res.code === 0 ||
      (Number.isFinite(code) && code >= 200 && code < 300)
    if (!isBusinessSuccess) {
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
          message.error(error.response?.data?.message || '未授权')
          if (shouldClearAuth(error)) {
            localStorage.removeItem('auth_token')
            localStorage.removeItem('user_info')
            window.location.href = '/login'
          }
          break
        case 403:
          message.error(error.response?.data?.message || '拒绝访问')
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
