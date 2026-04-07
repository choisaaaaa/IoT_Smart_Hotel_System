# MySQL 远程访问配置指南

> **版本**: v1.0.0\
> **更新日期**: 2026-04-07\
> **适用场景**: 云服务器 MySQL 远程访问配置

***

## 📋 目录

- [1. 配置 MySQL 绑定地址](#1-配置-mysql-绑定地址)
- [2. 创建远程用户](#2-创建远程用户)
- [3. 配置防火墙](#3-配置防火墙)
- [4. 测试远程连接](#4-测试远程连接)
- [5. 安全建议](#5-安全建议)

***

## 1. 配置 MySQL 绑定地址

### 1.1 编辑 MySQL 配置文件

```bash
# Ubuntu/Debian
sudo vim /etc/mysql/mysql.conf.d/mysqld.cnf

# CentOS/RHEL
sudo vim /etc/my.cnf
```

### 1.2 修改绑定地址

找到 `bind-address` 配置项，修改为：

```ini
[mysqld]
# 允许所有IP连接（生产环境建议指定具体IP）
bind-address = 0.0.0.0

# 或者只允许特定IP连接
# bind-address = 192.168.1.100
```

### 1.3 重启 MySQL 服务

```bash
sudo systemctl restart mysql
sudo systemctl status mysql
```

***

## 2. 创建远程用户

### 2.1 登录 MySQL

```bash
sudo mysql -u root -p
```

### 2.2 创建远程用户

```sql
-- 创建用户（允许所有IP连接）
CREATE USER 'iot_user'@'%' IDENTIFIED BY 'Iot2026.';

-- 或者创建用户（只允许特定IP连接）
CREATE USER 'iot_user'@'192.168.1.100' IDENTIFIED BY 'Iot2026.';

-- 授予数据库权限
GRANT ALL PRIVILEGES ON hotel_system.* TO 'iot_user'@'%';

-- 或者授予特定权限
-- GRANT SELECT, INSERT, UPDATE, DELETE ON hotel_system.* TO 'iot_user'@'%';

-- 刷新权限
FLUSH PRIVILEGES;

-- 查看用户
SELECT User, Host FROM mysql.user WHERE User='iot_user';

-- 退出
EXIT;
```

### 2.3 验证用户创建

```sql
-- 查看所有用户
SELECT User, Host FROM mysql.user;

-- 查看用户权限
SHOW GRANTS FOR 'iot_user'@'%';
```

***

## 3. 配置防火墙

### 3.1 配置 UFW 防火墙（Ubuntu）

```bash
# 安装 UFW（如果未安装）
sudo apt install -y ufw

# 设置默认策略
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 允许 MySQL 端口（仅内网IP，推荐）
sudo ufw allow from 10.0.0.0/8 to any port 3306
sudo ufw allow from 172.16.0.0/12 to any port 3306
sudo ufw allow from 192.168.0.0/16 to any port 3306

# 或者允许特定IP（不推荐，安全性较低）
# sudo ufw allow from 192.168.1.100 to any port 3306

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status verbose
```

### 3.2 配置云服务商安全组

**阿里云/腾讯云安全组配置**：

| 端口范围 | 协议 | 授权对象 | 说明 |
|---------|------|---------|------|
| 3306 | TCP | 10.0.0.0/8 | 内网IP段 |
| 3306 | TCP | 172.16.0.0/12 | 内网IP段 |
| 3306 | TCP | 192.168.0.0/16 | 内网IP段 |

**注意**: 生产环境建议只允许内网IP访问，不要开放给公网。

### 3.3 配置云服务器防火墙

**阿里云安全组**：
1. 进入 ECS 实例
2. 点击"安全组"
3. 添加入方向规则：
   - 端口范围: `3306`
   - 授权对象: `10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16`
   - 协议: `TCP`

**腾讯云安全组**：
1. 进入云服务器
2. 点击"安全组"
3. 添加入站规则：
   - 类型: `自定义`
   - 端口: `3306`
   - 来源: `10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16`

***

## 4. 测试远程连接

### 4.1 使用 MySQL 客户端测试

```bash
# 从远程服务器测试连接
mysql -h 8.134.166.69 -u iot_user -p

# 或者指定端口
mysql -h 8.134.166.69 -P 3306 -u iot_user -p
```

### 4.2 使用 Navicat/MySQL Workbench 测试

**连接参数**：

| 参数 | 值 | 说明 |
|------|-----|------|
| 主机名/IP | `8.134.166.69` | 服务器公网IP |
| 端口 | `3306` | MySQL 默认端口 |
| 用户名 | `iot_user` | 远程用户 |
| 密码 | `Iot2026.` | 用户密码 |
| 数据库 | `hotel_system` | 数据库名 |

### 4.3 使用命令行测试

```bash
# 测试连接
mysql -h 8.134.166.69 -u iot_user -p"Iot2026." -e "SELECT 1"

# 测试数据库
mysql -h 8.134.166.69 -u iot_user -p"Iot2026." -e "USE hotel_system; SHOW TABLES;"
```

***

## 5. 安全建议

### 5.1 基本安全措施

✅ **推荐配置**：

1. **限制 IP 访问**：只允许特定 IP 或内网 IP 访问
2. **使用强密码**：密码长度 ≥ 12 位，包含大小写字母、数字、特殊字符
3. **最小权限原则**：只授予必要的权限
4. **启用 SSL 加密**：生产环境建议启用 SSL
5. **定期备份**：定期备份数据库

❌ **不推荐配置**：

1. ❌ 允许所有 IP 访问 (`bind-address = 0.0.0.0`)
2. ❌ 使用 root 用户远程连接
3. ❌ 使用弱密码
4. ❌ 开放 3306 端口到公网

### 5.2 高级安全配置

#### 5.2.1 启用 SSL 加密

```sql
-- 查看 SSL 状态
SHOW VARIABLES LIKE '%ssl%';

-- 如果未启用，需要配置 SSL 证书
-- 生成 SSL 证书（略）
```

#### 5.2.2 限制连接数

```sql
-- 查看当前连接数
SHOW STATUS LIKE 'Threads_connected';

-- 限制用户连接数
ALTER USER 'iot_user'@'%' WITH MAX_CONNECTIONS_PER_HOUR 100;
```

#### 5.2.3 审计日志

```sql
-- 启用通用查询日志（谨慎使用，会影响性能）
SET GLOBAL general_log = 'ON';
SET GLOBAL general_log_file = '/var/log/mysql/query.log';

-- 启用慢查询日志
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;
```

### 5.3 监控和报警

```bash
# 监控数据库连接
watch -n 5 "mysql -u root -p -e 'SHOW PROCESSLIST;'"

# 监控数据库状态
mysql -u root -p -e "SHOW STATUS LIKE 'Threads_connected';"
mysql -u root -p -e "SHOW STATUS LIKE 'Aborted_connects';"
```

***

## 📋 配置检查清单

- [ ] MySQL 配置文件中 `bind-address = 0.0.0.0`
- [ ] MySQL 服务已重启
- [ ] 远程用户已创建
- [ ] 用户权限已授予
- [ ] 防火墙已配置允许 3306 端口
- [ ] 云服务商安全组已配置
- [ ] 远程连接测试成功
- [ ] SSL 加密已启用（生产环境）
- [ ] 数据库已备份

***

## 🎯 常见问题

### Q1: 连接被拒绝

**原因**: 防火墙或安全组未开放 3306 端口

**解决方案**：
```bash
# 检查防火墙
sudo ufw status

# 检查 MySQL 服务
sudo systemctl status mysql

# 检查绑定地址
sudo grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf
```

### Q2: 用户无法连接

**原因**: 用户权限配置错误

**解决方案**：
```sql
-- 检查用户
SELECT User, Host FROM mysql.user WHERE User='iot_user';

-- 重新授权
GRANT ALL PRIVILEGES ON hotel_system.* TO 'iot_user'@'%';
FLUSH PRIVILEGES;
```

### Q3: 连接超时

**原因**: 网络问题或 MySQL 配置问题

**解决方案**：
```bash
# 检查网络连通性
telnet 8.134.166.69 3306

# 检查 MySQL 超时配置
mysql -u root -p -e "SHOW VARIABLES LIKE 'wait_timeout';"
```

***

## 📚 参考资料

- [MySQL 官方文档](https://dev.mysql.com/doc/)
- [Ubuntu MySQL 文档](https://help.ubuntu.com/community/MySQL)
- [阿里云 MySQL 安全配置](https://help.aliyun.com/product/28146.html)

***

**最后更新**: 2026-04-07
