# 智慧酒店物联网控制系统 - 角色权限矩阵

> 版本: v1.0.0
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
| 查看预订 | R(全部) | R(本店) | R(本店) | R(自己的) | R(自己的) |
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

### 2.5 设备管理

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看设备 | R(全部) | R(本店) | R(本店) | R(入住房间) | R(入住房间) |
| 注册设备 | O | O | - | - | - |
| 审核设备 | U | U | - | - | - |
| 删除设备 | D | D | - | - | - |
| 发送设备指令 | O | O | O | O | O |
| 房卡操作 | - | O | O | - | - |

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
| 查看会员列表 | R(全部) | R(本店) | R(本店) | R(自己的) | R(自己的) |
| 查看自己的会员信息 | R | R | R | R | R |
| 查看会员状态 | R | R | R | R | R |
| 查看会员详情 | R | R | R | - | - |
| 创建/编辑会员 | CU | CU | - | - | - |
| 会员充值 | O | O | O | O | O |
| 会员签到 | O | O | O | O | O |
| 修改会员等级折扣 | U | - | - | - | - |

### 2.8 维修工单

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看工单 | R(全部) | R(本店) | R(本店) | R(自己房间的) | R(自己房间的) |
| 查看工单详情 | R(全部) | R(本店) | R(本店) | R(自己房间的) | R(自己房间的) |
| 创建工单 | C | C | C | C | C |
| 分配工单 | U | U | U | - | - |
| 更新工单状态 | U | U | U | - | - |
| 完成工单 | U | U | U | - | - |
| 删除工单 | D | D | D | - | - |

### 2.9 配送服务

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看配送单 | R(全部) | R(本店) | R(本店) | R(自己房间的) | R(自己房间的) |
| 查看配送详情 | R(全部) | R(本店) | R(本店) | R(自己房间的) | R(自己房间的) |
| 创建配送单 | C | C | C | C | C |
| 更新配送状态 | U | U | U | - | - |
| 完成配送 | U | U | U | - | - |

### 2.10 优惠券

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看优惠券 | R(全部) | R(本店) | R(本店) | R(公开) | R(公开) |
| 创建/编辑/删除优惠券 | CUD | CUD | - | - | - |
| 核销优惠券 | O | O | O | - | - |
| 发放优惠券给用户 | O | O | - | - | - |
| 领取优惠券 | - | - | - | O | O |

### 2.11 评价系统

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看评价 | R(全部) | R(本店) | R(本店) | R(公开) | R(公开) |
| 创建评价 | - | - | - | C(自己的订单) | C(自己的订单) |
| 编辑评价 | - | - | - | U(自己的) | U(自己的) |
| 删除评价 | D(任何) | - | - | D(自己的) | D(自己的) |
| 回复评价 | O | O | O | - | - |
| 评价申诉 | O | O | O | O | O |

### 2.12 支付系统

| 功能 | system_admin | hotel_admin | staff | customer | guest |
|------|:-----------:|:----------:|:-----:|:--------:|:-----:|
| 查看支付记录 | R(本店) | R(本店) | R(本店) | R(自己的) | R(自己的) |
| 查看支付详情 | R(本店) | R(本店) | R(本店) | R(自己的) | R(自己的) |
| 创建支付 | C | C | C | C | C |
| 执行支付 | O | O | O | O | O |
| 查看收入统计 | R | R | R | - | - |

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
6. **评价归属限制**: customer/guest只能评价/删除自己的订单评价
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
