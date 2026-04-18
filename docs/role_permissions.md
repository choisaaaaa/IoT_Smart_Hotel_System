# 智慧酒店物联网控制系统 - 角色权限矩阵

> 版本: v1.1.0
> 更新日期: 2026-04-19
> 适用范围: 后端服务、Web前端、App端

---

## 一、角色体系总览

| 角色标识 | 中文名 | 等级 | 默认AppMode | hotel_id规则 | 说明 |
|---------|--------|------|------------|-------------|------|
| `system_admin` | 系统管理员 | 5 | system | 0（可切换任意酒店） | 管理所有酒店，审核申请，系统配置 |
| `hotel_admin` | 酒店管理员 | 4 | manager | >0（限本酒店） | 管理所属酒店的业务和员工 |
| `staff` | 前台员工 | 3 | reception | >0（限本酒店） | 处理日常前台业务操作 |
| `customer` | 顾客 | 2 | customer | NULL或0 | 已登录顾客，预订房间、使用服务 |
| `guest` | 游客 | 1 | guest | 无 | 未登录/浏览模式，仅浏览酒店信息 |

**角色升级路径**: guest → customer（注册） → staff（员工绑定申请） / hotel_admin（创建酒店申请）

**模式切换规则**: 高等级角色可向下切换到任何低等级模式

---

## 二、功能权限矩阵

符号说明: **C**=创建, **R**=读取, **U**=更新, **D**=删除, **O**=操作, **-**=无权限

> ⚠️ 标注 🔴 的项表示**文档与代码不一致**，控制器中有对应逻辑但路由层 authorize() 未放行，详见第七节

### 2.1 酒店管理

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看酒店 | R(全部) | R(本店) | R(本店) | R(指定) | R(指定) |
| 创建酒店 | C | - | - | - | - |
| 编辑酒店 | U | U(本店) | - | - | - |
| 删除酒店 | D | - | - | - | - |
| 切换酒店 | O | - | - | - | - |
| 查看酒店统计 | R | R | R | - | - |
| 查看酒店报表 | R | R | R | - | - |

### 2.2 房间管理

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看房间列表 | R(全部) | R(本店) | R(本店) | R(指定酒店) | R(指定酒店) |
| 查看房间详情 | R(全部) | R(本店) | R(本店) | R(指定酒店) | R(指定酒店) |
| 查看入住房间 | R | R | R | R(自己的) | R(自己的) |
| 查看房间设备 | R | R | R | R(入住房间) | R(入住房间) |
| 创建房间 | C | C | - | - | - |
| 编辑房间 | U | U | - | - | - |
| 更新房间状态 | U | U | U | - | - |
| 删除房间 | D | D | - | - | - |

### 2.3 房型与楼层管理

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看房型 | R | R | R | R | R |
| 创建/编辑/删除房型 | CUD | CUD | - | - | - |
| 查看楼层 | R | R | R | R | R |
| 创建/编辑/删除楼层 | CUD | CUD | - | - | - |

### 2.4 预订管理

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看预订列表 | R(全部) | R(本店) | R(本店) | - | - |
| 查看自己的预订 | R | R | R | R 🔴 | R 🔴 |
| 查看预订详情 | R(全部) | R(本店) | R(本店) | R(自己的) | R(自己的) |
| 创建预订 | C | C | C | C | C |
| 确认预订 | U | U | U | - | - |
| 办理入住 | U | U | U | - | - |
| 在线办理入住 | - | - | - | O | O |
| 退房 | U | U | U | U | U |
| 取消预订 | U | U | U | U | U |
| 续住 | U | U | U | U | U |
| 计算续住价格 | O | O | O | O | O |
| 更新预订状态 | U | U | U | - | - |
| 查询价格 | O | O | O | O | O |

> 🔴 customer/guest 通过 `GET /bookings/my` 可查看自己的预订，但 `GET /bookings/` 列表接口的 authorize 不含 customer/guest

### 2.5 设备管理

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看设备 | R(全部) | R(本店) | R(本店) | - 🔴 | - 🔴 |
| 注册设备 | O | O | - | - | - |
| 审核设备 | U | U | - | - | - |
| 删除设备 | D | D | - | - | - |
| 发送设备指令 | O | O | O | - 🔴 | - 🔴 |
| 房卡操作 | - | O | O | - | - |

> 🔴 控制器中有 customer/guest 查看入住房间设备和发送指令的逻辑，但路由层 authorize() 排除了 customer/guest

### 2.6 用户管理

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看用户列表 | R(全部) | R(本店非顾客) | R(本店非顾客) | - | - |
| 查看用户详情 | R(全部) | R(本店) | R(本店) | - | - |
| 创建用户 | C(任意角色) | C(本店,限hotel_admin/staff/customer) | - | - | - |
| 编辑用户 | U | U(本店,不可授予system_admin) | - | - | - |
| 删除用户 | D | - | - | - | - |
| 重置用户密码 | U | U | - | - | - |

### 2.7 会员管理

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看会员列表 | R(全部) | R(本店) | R(本店) | - 🔴 | - 🔴 |
| 查看自己的会员信息 | R | R | R | R | R |
| 查看会员状态 | R | R | R | R | R |
| 查看会员详情 | R | R | R | - | - |
| 创建/编辑会员 | CU | CU | - | - | - |
| 会员充值 | O | O | O | O | O |
| 会员签到 | O | O | O | O | O |
| 修改会员等级折扣 | U | - | - | - | - |

> 🔴 控制器中 memberController.get 有 customer/guest 过滤逻辑（只返回自己的），但路由层 authorize() 排除了 customer/guest

### 2.8 维修工单

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看工单 | R(全部) | R(本店) | R(本店) | - 🔴 | - 🔴 |
| 查看工单详情 | R(全部) | R(本店) | R(本店) | - 🔴 | - 🔴 |
| 创建工单 | C | C | C | C | C |
| 分配工单 | U | U | U | - | - |
| 更新工单状态 | U | U | U | - | - |
| 完成工单 | U | U | U | - | - |
| 删除工单 | D | D | D | - | - |

> 🔴 customer/guest 可以创建工单但无法查看工单状态，体验不合理。控制器中有 customer/guest 过滤逻辑（只返回自己房间的），但路由层 authorize() 排除了 customer/guest

### 2.9 配送服务

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看配送单 | R(全部) | R(本店) | R(本店) | - 🔴 | - 🔴 |
| 查看配送详情 | R(全部) | R(本店) | R(本店) | - 🔴 | - 🔴 |
| 创建配送单 | C | C | C | C | C |
| 更新配送状态 | U | U | U | - | - |
| 完成配送 | U | U | U | - | - |

> 🔴 同维修工单，customer/guest 可以创建配送单但无法查看配送状态

### 2.10 优惠券

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看优惠券列表 | R(全部) | R(本店) | R(本店) | - 🔴 | - 🔴 |
| 查看自己的优惠券 | R | R | R | R | R |
| 查看优惠券详情 | R(全部) | R(本店) | R(本店) | - 🔴 | - 🔴 |
| 创建/编辑/删除优惠券 | CUD | CUD | - | - | - |
| 核销优惠券 | O | O | O | - | - |
| 发放优惠券给用户 | O | O | - | - | - |
| 领取优惠券 | - | - | - | O | O |

> 🔴 customer/guest 只能通过 `GET /coupons/me` 查看已领取的优惠券，无法浏览可领取的公开优惠券列表

### 2.11 评价系统

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看评价列表 | R(全部) | R(本店) | R(本店) | - 🔴 | - 🔴 |
| 查看评价详情 | R(全部) | R(本店) | R(本店) | R | R |
| 查看自己的评价 | R | R | R | R | R |
| 创建评价 | - | - | - | C(自己的订单) | C(自己的订单) |
| 编辑评价 | - | - | - | U(自己的) | U(自己的) |
| 删除评价 | D(任何) | - | - | - 🔴 | - 🔴 |
| 回复评价 | O | O | O | - | - |
| 评价申诉 | O | O | O | - 🔴 | - 🔴 |

> 🔴1 customer/guest 无法删除自己的评价（路由层 authorize 仅允许 hotel_admin/system_admin）
> 🔴2 customer/guest 无法创建评价申诉（控制器内部限制仅 hotel_admin/staff 可申诉）

### 2.12 支付系统

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看支付记录 | R(本店) | R(本店) | R(本店) | - 🔴 | - 🔴 |
| 查看支付详情 | R(本店) | R(本店) | R(本店) | - 🔴 | - 🔴 |
| 创建支付 | C | C | C | - 🔴 | - 🔴 |
| 执行支付 | O | O | O | O | O |
| 查看收入统计 | R | R | R | - | - |

> 🔴 customer/guest 只能执行已有支付的付款操作（PUT /:id/pay），无法查看支付记录/详情或创建支付订单。控制器中有 customer/guest 过滤逻辑，但路由层 authorize() 排除了 customer/guest

### 2.13 通话系统

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 发起通话 | O(跨店) | O(本店) | O(本店) | O | O |
| 拨打普通用户 | **禁止** | **禁止** | **禁止** | **禁止** | **禁止** |
| 查看活跃通话 | R | R | R | - | - |
| 查看通话历史 | R | R | R | - | - |
| 查看通话统计 | R | R | R | - | - |
| 接听/拒绝/挂断 | O | O | O | O | O |

### 2.14 环境监测

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看环境数据 | R | R | R | - | - |
| 查看火警记录 | R | R | R | - | - |
| 确认火警 | - | O | O | - | - |
| 解除火警 | - | O | O | - | - |
| 查看环境设备 | R | R | R | - | - |
| 控制环境设备 | - | O | O | - | - |
| 查看能耗数据 | R | R | R | - | - |
| 查看事件日志 | R | R | R | - | - |
| 查看环境仪表盘 | R | R | R | - | - |

### 2.15 系统管理

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看系统配置 | R | R | R | R | R |
| 修改系统配置 | U | - | - | - | - |
| MQTT日志查看 | R | R | - | - | - |
| MQTT消息发送 | O | O | - | - | - |
| MQTT状态查看 | R | R | - | - | - |
| AI知识库查看/编辑 | O | O | - | - | - |
| AI知识库删除 | D | - | - | - | - |
| 价格日历设置 | O | O | - | - | - |
| 价格日历查看(今日) | R | R | R | - | - |
| 价格日历更新(今日) | U | U | U | - | - |
| 房价方案管理 | CUD | CUD | CUD | - | - |

### 2.16 角色与认证

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 登录/注册 | O | O | O | O | - |
| 提交角色申请 | - | - | - | O | O |
| 审核角色申请(员工绑定) | - | O(本店) | - | - | - |
| 审核角色申请(创建酒店) | O | - | - | - | - |
| 切换酒店 | O | - | - | - | - |

---

## 三、前端页面权限

### 3.1 Web端路由权限

| 路由前缀 | 页面类型 | 允许角色 |
|---------|---------|---------|
| `/system/*` | 系统管理端 | system_admin |
| `/hotel-admin/*` | 酒店管理端 | hotel_admin, system_admin |
| `/reception/*` | 前台端 | staff, hotel_admin, system_admin |
| `/guest/*` | 顾客端 | customer, guest（含未登录） |

### 3.2 Web端角色默认跳转

| 角色 | 登录后跳转 |
|------|----------|
| system_admin | `/system/dashboard` |
| hotel_admin | `/hotel-admin/dashboard` |
| staff | `/reception/dashboard` |
| customer | `/guest/booking` |
| 未登录 | `/guest/booking?login=1` |

### 3.3 移动端AppMode权限

| AppMode | 底部导航 | 可切换到此模式的最低角色等级 |
|---------|---------|------------------------|
| guest | 首页 / 逛逛 / 我的 | 等级0（未登录） |
| customer | 首页 / 逛逛 / 服务 / 会员 / 我的 | 等级2（customer） |
| reception | 首页 / 逛逛 / 服务 / 前台 | 等级3（staff） |
| manager | 首页 / 逛逛 / 服务 / 管理 | 等级4（hotel_admin） |
| system | 首页 / 逛逛 / 系统 | 等级5（system_admin） |

---

## 四、数据范围限制

| 角色 | 酒店范围 | 用户范围 | 预订范围 | 设备范围 |
|------|---------|---------|---------|---------|
| system_admin | 全部酒店 | 全部用户 | 全部预订 | 全部设备 |
| hotel_admin | 本酒店 | 本酒店用户 | 本酒店预订 | 本酒店设备 |
| staff | 本酒店 | 本酒店用户 | 本酒店预订 | 本酒店设备 |
| customer | 指定酒店 | 自己 | 自己的预订 | 入住房间设备 |
| guest | 指定酒店 | 自己 | 自己的预订 | 入住房间设备 |

---

## 五、特殊限制规则

1. **禁止拨打普通用户**: 任何角色发起通话时，如果被叫方是customer或guest角色，直接返回403错误
2. **注册固定角色**: 注册接口固定创建customer角色，角色升级需通过申请审核
3. **酒店隔离**: 非system_admin角色只能操作本酒店数据
4. **环境操作限制**: 火警确认/解除和设备控制仅hotel_admin和staff可操作（system_admin不可）
5. **房卡操作限制**: 仅hotel_admin和staff可操作房卡
6. **评价归属限制**: customer/guest只能评价自己的订单评价
7. **用户创建限制**: hotel_admin创建用户时不可授予system_admin角色
8. **知识库删除限制**: 仅system_admin可删除知识库条目
9. **会员折扣修改**: 仅system_admin可修改会员等级折扣配置
10. **WebSocket柜台登录**: customer/guest无法以柜台身份登录WebSocket

---

## 六、数据库角色权限定义

### 6.1 设计文档定义（数组格式）

| 角色 | 权限列表 |
|------|---------|
| system_admin | read, write, delete, manage_users, manage_roles, manage_devices, view_reports, system_config |
| hotel_admin | read, write, manage_bookings, manage_rooms, manage_orders, view_reports, manage_guests, hotel_manage |
| staff | read, write, manage_bookings, manage_rooms, manage_orders, view_reports, manage_guests |
| customer | read, manage_own_bookings, manage_own_profile, use_services |
| guest | browse_hotels, browse_rooms |

### 6.2 实际运行数据（对象格式）

| 角色 | 权限对象 |
|------|---------|
| system_admin | {"all": true} |
| hotel_admin | {"room_manage": true, "hotel_manage": true} |
| staff | {"booking_manage": true, "checkin_manage": true} |
| customer | {"guest_service": true} |
| guest | {"browse_hotels": true, "browse_rooms": true} |

> **注意**: 当前数据库中权限格式（对象）与设计文档（数组）不一致，后续需统一。

---

## 七、⚠️ 权限问题与合理性分析

以下问题基于**酒店管理策略**角度分析，按严重程度排序。

### 🔴 严重问题（影响核心用户体验）

#### 问题1: 顾客无法查看设备状态和控制设备

**现状**: 路由层 `authorize()` 排除了 customer/guest，但控制器中有完整的入住房间设备查询和控制逻辑。

**合理性分析**: 在智慧酒店场景中，顾客通过App控制房间设备（灯光、空调、窗帘等）是**核心功能**。顾客无法控制设备将严重影响入住体验。这是必须修复的问题。

**建议**: 在路由层 `GET /devices`、`GET /devices/:id`、`POST /devices/:id/command` 中加入 customer/guest 角色，控制器中已有入住房间过滤逻辑。

#### 问题2: 顾客无法查看维修工单和配送单状态

**现状**: customer/guest 可以创建工单/配送单，但无法查看其处理进度。

**合理性分析**: 顾客报修后无法查看维修进度、叫配送后无法查看配送状态，这是**严重体验缺陷**。酒店行业中，客人提交服务请求后查看处理进度是基本需求。

**建议**: 在路由层 `GET /maintenance`、`GET /maintenance/:id`、`GET /delivery`、`GET /delivery/:id` 中加入 customer/guest 角色。

#### 问题3: 顾客无法查看支付记录

**现状**: customer/guest 只能执行支付（PUT /:id/pay），无法查看支付记录/详情或创建支付订单。

**合理性分析**: 顾客无法查看自己的消费记录，无法确认账单金额，这在酒店行业中是**不可接受的**。客人需要清楚了解自己的消费明细。

**建议**: 在路由层 `GET /payments`、`GET /payments/:id`、`POST /payments` 中加入 customer/guest 角色。

### 🟡 中等问题（影响部分功能体验）

#### 问题4: 顾客无法删除自己的评价

**现状**: `DELETE /reviews/:id` 的 authorize 仅允许 hotel_admin/system_admin，但控制器中有 customer/guest 删除自己评价的逻辑。

**合理性分析**: 允许用户删除自己的评价是常见做法。虽然酒店可能希望保留评价数据，但完全不允许删除自己的评价可能引起用户不满。

**建议**: 在路由层 `DELETE /reviews/:id` 中加入 customer/guest 角色，控制器已有归属检查。

#### 问题5: 顾客无法浏览公开评价列表

**现状**: `GET /reviews/` 的 authorize 排除了 customer/guest。

**合理性分析**: 在预订酒店前，顾客需要查看其他人的评价来决策。无法浏览评价列表会影响预订转化率。但可通过 `GET /:id` 查看单条评价，前端可能已有替代方案。

**建议**: 考虑在路由层加入 customer/guest，或提供专门的公开评价接口。

#### 问题6: 顾客无法浏览可领取的优惠券

**现状**: `GET /coupons/` 的 authorize 排除了 customer/guest，只能通过 `/me` 查看已领取的。

**合理性分析**: 顾客无法发现和领取新优惠券，降低了营销效果。酒店行业优惠券是重要的促销手段。

**建议**: 在路由层 `GET /coupons/` 中加入 customer/guest 角色，控制器已有公开优惠券过滤逻辑。

#### 问题7: 评价申诉仅限酒店方

**现状**: 评价申诉（POST /appeals）控制器内部限制仅 hotel_admin/staff 可申诉。

**合理性分析**: 在酒店行业中，评价申诉通常由酒店方发起（对差评提出异议），这是合理的。但顾客也可能需要对恶意回复进行申诉。当前设计偏向酒店方，可接受。

**建议**: 维持现状，或考虑增加顾客申诉渠道。

### 🟢 低优先级问题

#### 问题8: 顾客无法查看会员列表

**现状**: `GET /members/` 的 authorize 排除了 customer/guest。

**合理性分析**: 顾客不需要查看其他会员的列表，通过 `/me` 查看自己的会员信息已足够。当前设计合理。

**建议**: 维持现状。

#### 问题9: 预订列表接口权限

**现状**: `GET /bookings/` 排除了 customer/guest，但有 `GET /bookings/my` 替代。

**合理性分析**: 顾客不需要查看管理端的预订列表，`/my` 接口已满足需求。当前设计合理。

**建议**: 维持现状，但控制器中 `GET /bookings/` 的 customer/guest 逻辑可清理。

### 问题汇总

| 序号 | 严重程度 | 模块 | 问题 | 建议操作 |
|------|---------|------|------|---------|
| 1 | 🔴 严重 | 设备管理 | 顾客无法查看/控制房间设备 | 路由层加入 customer/guest |
| 2 | 🔴 严重 | 维修工单 | 顾客无法查看工单进度 | 路由层加入 customer/guest |
| 3 | 🔴 严重 | 配送服务 | 顾客无法查看配送状态 | 路由层加入 customer/guest |
| 4 | 🔴 严重 | 支付系统 | 顾客无法查看支付记录 | 路由层加入 customer/guest |
| 5 | 🟡 中等 | 评价系统 | 顾客无法删除自己的评价 | 路由层加入 customer/guest |
| 6 | 🟡 中等 | 评价系统 | 顾客无法浏览公开评价 | 路由层加入 customer/guest 或新增公开接口 |
| 7 | 🟡 中等 | 优惠券 | 顾客无法浏览可领取优惠券 | 路由层加入 customer/guest |
| 8 | 🟢 低 | 评价申诉 | 顾客无法申诉 | 维持现状或增加渠道 |
| 9 | 🟢 低 | 会员列表 | 顾客无法查看会员列表 | 维持现状 |
| 10 | 🟢 低 | 预订列表 | 顾客无法查看管理端列表 | 维持现状，清理死代码 |
