import axios from 'axios'
import type { ApiResponse } from '@/types'
import { message } from 'ant-design-vue'

function shouldClearAuth(error: any): boolean {
  const msg = String(error?.response?.data?.message || '').toLowerCase()
  if (!msg) {
    return false
  }
  // 只有当明确提示令牌过期或非法时才清除，避免因偶发的 header 丢失导致全站登出
  return (
    msg.includes('令牌验证失败') ||
    msg.includes('token expired') ||
    msg.includes('invalid token') ||
    msg.includes('jwt expired')
  )
}

function getAuthToken(): string {
  // 优先尝试从 localStorage 直接获取
  let token = localStorage.getItem('auth_token')

  // 如果没有，尝试从 user_info 中恢复
  if (!token || token === 'null' || token === 'undefined' || token === '') {
    const rawUserInfo = localStorage.getItem('user_info')
    if (rawUserInfo) {
      try {
        const parsed = JSON.parse(rawUserInfo)
        token = parsed?.token || parsed?.accessToken || ''
      } catch (_) {
        token = ''
      }
    }
  }

  if (!token) return ''

  // 确保返回的是干净的字符串，不包含 "Bearer " 前缀
  // 兼容各种可能的错误格式，如 "Bearer null", "Bearer undefined"
  if (typeof token === 'string' && token.toLowerCase().startsWith('bearer ')) {
    token = token.substring(7).trim()
  }

  // 最终验证：如果 token 看起来不合法，返回空
  if (token === 'null' || token === 'undefined' || token === '') {
    return ''
  }

  return token
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
      // 更加标准且鲁棒的 Header 设置方式
      if (typeof config.headers.set === 'function') {
        config.headers.set('Authorization', `Bearer ${token}`)
      } else {
        if (!config.headers) {
          config.headers = {} as any
        }
        config.headers.Authorization = `Bearer ${token}`
      }
    }

    // 在 GET 请求后添加随机时间戳，彻底避免浏览器/代理缓存 304 问题
    if (config.method === 'get') {
      config.params = {
        ...config.params,
        _t: Date.now()
      }
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
      const msg = res.message || '请求失败'
      message.error(msg.length > 30 ? msg.substring(0, 30) + '...' : msg)
      return Promise.reject(new Error(msg))
    }
    return response.data
  },
  (error) => {
    console.error('[Axios Response Error]', error.response || error)
    if (error.response) {
      const status = error.response.status
      const serverMsg = error.response?.data?.message

      switch (status) {
        case 401:
          message.error(serverMsg || '登录已过期，请重新登录')
          if (shouldClearAuth(error)) {
            localStorage.removeItem('auth_token')
            localStorage.removeItem('user_info')
            window.location.href = '/guest/booking?login=1'
          }
          break
        case 403:
          message.error(serverMsg || '无权限访问')
          break
        case 404:
          message.error(serverMsg || '请求的资源不存在')
          break
        case 400:
          message.error(serverMsg || '请求参数错误')
          break
        case 500:
          message.error('服务器异常，请稍后重试')
          break
        default:
          message.error(serverMsg || `请求失败(${status})`)
      }
    } else if (error.code === 'ECONNABORTED') {
      message.error('请求超时，请稍后重试')
    } else {
      message.error('网络连接异常')
    }
    return Promise.reject(error)
  }
)

export default request
