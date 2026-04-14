import { createApp } from 'vue'
import { createPinia } from 'pinia'
import Antd from 'ant-design-vue'
import 'ant-design-vue/dist/reset.css'

import App from './App.vue'
import router from './router'
import './assets/global.css'
import { initWebSocket } from './utils/websocket'
import { message } from 'ant-design-vue'

// 全局消息配置
message.config({
  duration: 3,
  maxCount: 2, // 最大存留数调成 2
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