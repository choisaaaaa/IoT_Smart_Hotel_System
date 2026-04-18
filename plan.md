# 角色字段问题分析与修复计划

## 一、当前角色体系总览

### 五大标准角色 (CANONICAL_ROLES) - 目标状态

| 角色标识 | 中文名 | 等级 | 默认AppMode | 说明 |
|---------|--------|------|------------|------|
| `system_admin` | 系统管理员 | 5 | system | 全部权限，可跨酒店操作 |
| `hotel_admin` | 酒店管理员 | 4 | manager | 酒店管理权限，限本酒店 |
| `staff` | 前台员工 | 3 | reception | 业务操作权限，限本酒店 |
| `customer` | 顾客 | 2 | customer | 已登录顾客，完整服务权限 |
| `guest` | 游客 | 1 | guest | 未登录/浏览模式，仅浏览权限 |

### 角色别名映射（后端/前端/移动端均有 normalizeRole 函数）

| 别名 | 标准化结果 |
|------|-----------|
| system, sys_admin, systemadmin, super_admin, platform_admin | `system_admin` |
| admin, manager, hotel_manager, hoteladmin | `hotel_admin` |
| receptionist, reception, front_desk, frontdesk | `staff` |
| user | `customer` |
| visitor | `guest` |

---

## 二、发现的问题

### 问题1: 数据库 users 表中存在非标准角色值 🔴 严重

**现状**: 用户 id=35 (手机号13900000008) 的 `role` 字段值为 `user`，而非标准的 `customer`。

```sql
-- 问题数据
id=35, username='13900000008', role='user', hotel_id=1
```

**影响**: 虽然后端有 `normalizeRole` 函数会将 `user` 映射为 `customer`，但如果某些代码路径直接比较 `role` 字符串而未经过规范化，就会导致权限判断失败。

**修复方案**: 将数据库中 `role='user'` 的记录更新为 `role='customer'`。

### 问题2: `guest` 未作为独立角色存在 🔴 严重

**现状**: 
- 后端 `role.ts` 中 `guest` 被映射为 `customer`（别名），不是独立角色
- 前端 `auth.ts` 中 `guest` 被映射为 `customer`（别名），不是独立角色
- 移动端 `AppRoles` 中 `guest` 被映射为 `customer`，但 `AppMode.guest` 是独立模式
- 数据库 `roles` 表中没有 `guest` 角色记录
- 数据库规范文档中 `role` 字段只允许4种取值

**影响**: 
- 游客和顾客的权限无法区分
- 移动端 `AppMode.guest` 与后端角色不对应
- 权限分配可能出现混乱

**修复方案**: 
1. 在数据库 `roles` 表中添加 `guest` 角色
2. 后端 `CANONICAL_ROLES` 增加 `GUEST: 'guest'`
3. 前端 `CANONICAL_ROLES` 增加 `GUEST: 'guest'`
4. 移动端 `AppRoles` 增加 `guest` 常量
5. 更新 `normalizeRole` 映射：`guest` 不再映射为 `customer`，而是保持为 `guest`
6. 更新数据库规范文档

### 问题3: 移动端旧版角色常量不一致 🟡 中等

**文件**: `mobile/iot_hotel_app/lib/core/constants/app_constants.dart`

```dart
// 旧版 - 使用非标准角色名
static const List<String> userRoles = ['admin', 'system', 'receptionist', 'staff', 'user'];
static Map<String, String> roleNames = {
  'admin': '管理员',
  'system': '系统管理员',
  'receptionist': '前台',
  'staff': '员工',
  'user': '住客',
};
```

**影响**: 如果有代码使用这个旧版列表进行角色判断，会导致匹配失败。

**修复方案**: 更新为标准角色名（5种），与 `CANONICAL_ROLES` 保持一致。

### 问题4: 前端 websocket.ts 使用非标准角色名 🟡 中等

**文件**: `frontend/iot-hotel-web/src/utils/websocket.ts`

```typescript
// 第11行 - 包含非标准角色名 'admin', 'staff', 'manager', 'reception'
['admin', 'staff', 'manager', 'reception', 'hotel_admin', 'system_admin'].includes(role)
```

**影响**: 直接使用原始角色字符串比较时可能不一致。

**修复方案**: 改为使用规范化后的标准角色名进行比较。

### 问题5: roles 表权限格式不一致 🟡 中等

**数据库实际数据**:
```json
// hotel_admin: {"room_manage": true, "hotel_manage": true}
// staff: {"booking_manage": true, "checkin_manage": true}
// customer: {"guest_service": true}
// system_admin: {"all": true}
```

**设计文档定义** (data_only.sql):
```json
// system_admin: ["read","write","delete","manage_users","manage_roles","manage_devices","view_reports","system_config"]
// hotel_admin: ["read","write","manage_bookings","manage_rooms","manage_orders","view_reports","manage_guests","hotel_manage"]
// staff: ["read","write","manage_bookings","manage_rooms","manage_orders","view_reports","manage_guests"]
// customer: ["read","manage_own_bookings","manage_own_profile","use_services"]
```

**影响**: 权限格式从数组变成了对象，权限键名也完全不同。如果后端代码依赖特定权限格式进行判断，可能导致权限控制失效。

**修复方案**: 需要确认后端代码实际使用的权限格式，统一 roles 表中的权限定义。

### 问题6: roles 表 id 不连续 🟢 低

roles 表的 id 为 1, 3, 4, 5，缺少 id=2，说明曾有角色被删除。这不影响功能，但值得记录。

---

## 三、修复计划

### 步骤1: 修复数据库中非标准角色值
- 执行 SQL: `UPDATE users SET role = 'customer' WHERE role = 'user';`
- 验证: `SELECT * FROM users WHERE role NOT IN ('system_admin', 'hotel_admin', 'staff', 'customer', 'guest');`

### 步骤2: 在数据库中添加 guest 角色
- 在 `roles` 表中插入 `guest` 角色记录
- 权限定义: `{"browse_hotels": true, "browse_rooms": true}`（仅浏览权限）
- 更新数据库规范文档，`role` 字段允许5种取值

### 步骤3: 修复移动端代码（可直接修改）
- 更新 `app_constants.dart` 中的 `userRoles` 和 `roleNames` 为5种标准角色名
- 更新 `auth_state_notifier.dart` 中 `AppRoles` 增加 `guest` 常量
- 更新 `normalizeRole` 映射：`guest` 保持为 `guest`，不再映射为 `customer`
- 更新 `roleToLevel`：`guest` 等级为 1，`customer` 等级为 2

### 步骤4: 修复前端/后端代码（需要用户允许）
- 后端 `role.ts`: `CANONICAL_ROLES` 增加 `GUEST: 'guest'`，`normalizeRole` 中 `guest` 不再映射为 `customer`
- 前端 `auth.ts`: 同步更新
- 前端 `websocket.ts`: 使用标准角色名
- 各 Controller 中的角色判断逻辑适配

---

## 四、修改范围与权限

根据项目规则"不要修改web端的代码以及后端接口内容除非我允许"：

- ✅ 数据库数据的修复（直接修复数据问题）
- ✅ 移动端代码的修改（app代码可以在mobile目录下开发）
- ❓ 后端代码修改（需要用户允许）
- ❓ 前端代码修改（需要用户允许）
- ❓ 数据库规范文档修改（需要确认是否与代码同步修改）

---

## 五、建议立即执行的修复

1. **数据库修复**（无需修改代码）- 将 `role='user'` 改为 `customer`，添加 `guest` 角色记录
2. **移动端修复**（app代码，可直接修改）- 更新旧版角色常量，增加 `guest` 独立角色
3. **前端/后端修复**（需要用户允许后才能修改）- 增加 `guest` 为独立角色
