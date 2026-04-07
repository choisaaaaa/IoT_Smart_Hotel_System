# MySQL 公网访问配置指南

> **问题**: 公网无法访问 MySQL  
> **版本**: v1.0.0  
> **更新日期**: 2026-04-07

***

## 🔍 问题分析

**症状**: 公网无法连接 MySQL

**原因**: 
1. 防火墙只允许内网 IP 访问
2. 云服务商安全组未开放公网访问
3. MySQL 只监听内网 IP

---

## 🚀 快速配置（仅用于测试环境）

### ⚠️ 警告：生产环境不建议开放 MySQL 到公网！

如果必须开放，请：
1. 使用强密码
2. 限制特定 IP
3. 启用 SSL 加密
4. 定期备份

---

## 🔧 配置步骤

### 1️⃣ **配置防火墙允许公网访问**

```bash
# 允许所有 IP 访问（不推荐，仅用于测试）
sudo ufw allow 3306

# 或者只允许特定 IP（推荐）
sudo ufw allow from 8.134.166.69 to any port 3306

# 重启防火墙
sudo ufw reload

# 查看状态
sudo ufw status verbose
```

**输出示例**：
```
3306                     ALLOW       Anywhere
3306 (v6)                ALLOW       Anywhere (v6)
```

---

### 2️⃣ **配置云服务商安全组**

#### 阿里云

1. 登录阿里云控制台
2. 进入 ECS 实例
3. 点击"安全组"
4. 添加入方向规则：

| 端口范围 | 协议 | 授权对象 | 说明 |
|---------|------|---------|------|
| 3306 | TCP | 0.0.0.0/0 | 允许所有 IP（测试） |
| 3306 | TCP | 8.134.166.69/32 | 允许特定 IP（生产） |

#### 腾讯云

1. 登录腾讯云控制台
2. 进入云服务器
3. 点击"安全组"
4. 添加入站规则：

| 类型 | 端口 | 来源 | 说明 |
|------|------|------|------|
| 自定义 | 3306 | 0.0.0.0/0 | 允许所有 IP（测试） |
| 自定义 | 3306 | 8.134.166.69/32 | 允许特定 IP（生产） |

---

### 3️⃣ **验证 MySQL 监听地址**

```bash
# 检查监听地址
sudo netstat -tlnp | grep mysql
```

**正常输出**：
```
tcp        0      0 0.0.0.0:3306            0.0.0.0:*               LISTEN      3874/mysqld
```

**如果显示** `127.0.0.1:3306`，说明配置错误，需要修改 `bind-address`。

---

### 4️⃣ **创建远程用户**

```bash
sudo mysql -u root -p
```

```sql
-- 创建用户（允许所有IP连接）
CREATE USER 'iot_user'@'%' IDENTIFIED BY 'Iot2026.';

-- 授予权限
GRANT ALL PRIVILEGES ON hotel_system.* TO 'iot_user'@'%';

-- 刷新权限
FLUSH PRIVILEGES;

-- 查看用户
SELECT User, Host FROM mysql.user WHERE User='iot_user';

-- 退出
EXIT;
```

---

### 5️⃣ **测试公网连接**

```bash
# 从公网客户端测试
mysql -h 8.134.166.69 -u iot_user -p -P 3306
```

---

## 🔒 安全配置（生产环境）

### 1️⃣ **限制特定 IP 访问**

```bash
# 只允许特定 IP
sudo ufw allow from 8.134.166.69 to any port 3306

# 删除允许所有 IP 的规则
sudo ufw delete allow 3306
```

### 2️⃣ **使用强密码**

```sql
-- 创建强密码用户
CREATE USER 'iot_user'@'%' IDENTIFIED BY 'YourStrongPassword123!@#';

-- 或者使用更复杂的密码
CREATE USER 'iot_user'@'%' IDENTIFIED BY 'MyS3cur3P@ssw0rd!2026';
```

### 3️⃣ **启用 SSL 加密**

```sql
-- 查看 SSL 状态
SHOW VARIABLES LIKE '%ssl%';

-- 如果未启用，需要配置 SSL 证书
-- 生成 SSL 证书（略）
```

### 4️⃣ **限制连接数**

```sql
-- 限制用户连接数
ALTER USER 'iot_user'@'%' WITH MAX_CONNECTIONS_PER_HOUR 100;
ALTER USER 'iot_user'@'%' WITH MAX_UPDATES_PER_HOUR 1000;
ALTER USER 'iot_user'@'%' WITH MAX_QUERIES_PER_HOUR 10000;
```

---

## 📊 连接测试

### ✅ 本地连接测试

```bash
mysql -u iot_user -p -h 127.0.0.1
```

### ✅ 公网连接测试

```bash
# 从公网客户端测试
mysql -h 8.134.166.69 -u iot_user -p -P 3306

# 或者使用 Navicat/MySQL Workbench
# 主机: 8.134.166.69
# 端口: 3306
# 用户名: iot_user
# 密码: Iot2026.
```

---

## 🎯 常见问题

### Q1: 连接超时

**原因**: 防火墙或安全组未开放端口

**解决方案**：
```bash
# 检查防火墙
sudo ufw status

# 检查安全组
# 登录云服务商控制台查看安全组规则
```

### Q2: 连接被拒绝

**原因**: MySQL 未监听公网 IP

**解决方案**：
```bash
# 检查监听地址
sudo netstat -tlnp | grep mysql

# 确保监听 0.0.0.0:3306
```

### Q3: 用户无法连接

**原因**: 用户权限配置错误

**解决方案**：
```sql
-- 检查用户
SELECT User, Host FROM mysql.user WHERE User='iot_user';

-- 重新授权
GRANT ALL PRIVILEGES ON hotel_system.* TO 'iot_user'@'%';
FLUSH PRIVILEGES;
```

---

## 📋 配置检查清单

- [x] MySQL 监听 `0.0.0.0:3306`
- [ ] 防火墙允许 3306 端口
- [ ] 云服务商安全组允许 3306 端口
- [ ] 远程用户已创建
- [ ] 公网连接测试成功

---

## 🎯 快速配置命令（测试环境）

```bash
# 1. 允许所有 IP 访问（仅测试）
sudo ufw allow 3306

# 2. 重启防火墙
sudo ufw reload

# 3. 创建远程用户
sudo mysql -u root -p -e "CREATE USER 'iot_user'@'%' IDENTIFIED BY 'Iot2026.'; GRANT ALL PRIVILEGES ON hotel_system.* TO 'iot_user'@'%'; FLUSH PRIVILEGES;"

# 4. 测试连接
mysql -h 8.134.166.69 -u iot_user -p -P 3306
```

---

## ⚠️ 安全建议

1. **不要在生产环境开放 MySQL 到公网**
2. **使用强密码**：长度 ≥ 12 位，包含大小写字母、数字、特殊字符
3. **限制 IP 访问**：只允许特定 IP
4. **启用 SSL 加密**：生产环境必须启用
5. **定期备份**：定期备份数据库
6. **监控连接**：定期检查数据库连接日志

---

## 📚 参考资料

- [MySQL 官方文档](https://dev.mysql.com/doc/)
- [Ubuntu MySQL 文档](https://help.ubuntu.com/community/MySQL)
- [阿里云 MySQL 安全配置](https://help.aliyun.com/product/28146.html)

***

**最后更新**: 2026-04-07
