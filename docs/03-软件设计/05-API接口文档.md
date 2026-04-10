# 智慧酒店物联网控制系统 - API 接口文档

## 📋 接口概述

本系统提供标准的 RESTful API 接口，所有请求均通过 HTTP/HTTPS 协议通信，数据交换格式统一为 `JSON`。

- **基准路径**：`/api/v1`
- **认证方式**：请求头携带 `Authorization: Bearer <token>`
- **成功响应格式**：
  ```json
  {
    "code": 200,
    "message": "success",
    "data": { ... }
  }
  ```

---

## 🏗️ 核心接口模块

### 1. 认证与账户 (`/auth`)
- `POST /auth/login`: 用户登录 (手机号/密码)，返回 JWT Token。
- `GET /auth/me`: 获取当前登录用户信息及权限。
- `POST /auth/register`: 新用户注册。
- `POST /auth/logout`: 登出系统，注销会话。

### 2. 酒店资源管理 (`/hotels`, `/rooms`, `/room-types`)
- `GET /hotels/search`: 根据目的地和日期搜索酒店。
- `GET /hotels/:id/rooms/availability`: 查询指定酒店的房型余量及价格。
- `GET /rooms`: 获取房间列表 (支持分页及状态筛选)。
- `PATCH /rooms/:id/status`: 更新房间状态 (空闲/在住/清洁等)。
- `GET /room-types`: 获取所有房型定义及基础价格。

### 3. 物联网设备控制 (`/devices`)
- `GET /devices`: 获取设备列表及在线状态。
- `POST /devices/:id/control`: 发送控制指令 (指令通过 MQTT 转发至硬件)。
- `GET /devices/:id/history`: 查询设备的传感器历史数据。
- `DELETE /devices/:id`: 移除设备。

### 4. 业务订单系统 (`/bookings`, `/payments`)
- `POST /bookings`: 创建客房预订。
- `GET /bookings/calculate-price`: 预计算订单总价 (考虑优惠券及会员折扣)。
- `PUT /bookings/:id/checkin`: 办理入住，激活房卡。
- `PUT /bookings/:id/checkout`: 办理退房，结清账单。
- `POST /payments/create`: 发起支付请求。

### 5. 客房服务与通信 (`/delivery`, `/maintenance`, `/calls`)
- `POST /delivery`: 下单送物服务。
- `POST /maintenance`: 提交报修工单。
- `GET /calls/active`: 获取当前正在进行的语音通话。
- `POST /calls/initiate`: 发起呼叫请求。

### 6. AI 智能管家 (`/ai-butler`)
- `POST /ai-butler/chat`: 发送文本/语音指令，获取 AI 响应及 Function Calling 结果。
- `GET /ai-butler/config`: 获取 AI 管家的个性化配置。

---

## 📡 实时推送 (WebSocket)

- **事件列表**：
  - `device_status_change`: 设备在线/离线或状态变更提醒。
  - `new_order_notice`: 收到新的预订或服务订单。
  - `emergency_alarm`: SOS 报警信息实时推送。
  - `voice_call_signal`: 语音通话信令交换。

---

## 🛠️ 错误处理

| 状态码 | 说明 | 处理建议 |
|:---:|:---|:---|
| `400` | 参数错误 | 检查请求体字段及格式 |
| `401` | 未授权 | 重新登录获取 Token |
| `403` | 权限不足 | 检查当前角色是否有权访问该接口 |
| `404` | 资源不存在 | 确认 URL 或资源 ID 正确 |
| `500` | 服务器内部错误 | 联系后端管理员排查日志 |
