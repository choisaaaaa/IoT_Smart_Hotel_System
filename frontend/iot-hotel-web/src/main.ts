import { createApp } from 'vue'
import { createPinia } from 'pinia'
import Antd from 'ant-design-vue'
import 'ant-design-vue/dist/reset.css'

import App from './App.vue'
import router from './router'
import './assets/global.css'
import './assets/global-notify.css'
import { initWebSocket } from './utils/websocket'
import { message, notification } from 'ant-design-vue'

message.config({
  duration: 3,
  maxCount: 2,
})

notification.config({
  placement: 'topRight',
  duration: 4.5,
  maxCount: 3,
  top: '24px',
  right: '24px',
})
const app = createApp(App)

app.use(createPinia())
app.use(router)
app.use(Antd)

// 自动初始化 WebSocket，如果有 token 说明已经登录过
if (localStorage.getItem('auth_token')) {
  initWebSocket()
}

app.mount('#app')