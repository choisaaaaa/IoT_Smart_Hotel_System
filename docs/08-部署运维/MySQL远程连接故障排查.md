# MySQL 远程连接故障排查指南

> **错误**: `2013 - Lost connection to server at 'handshake: reading initial communication packet'`  
> **版本**: v1.0.0  
> **更新日期**: 2026-04-07

***

## 🔍 错误分析

**错误信息**: `Lost connection to server at 'handshake: reading initial communication packet'`

**常见原因**：
1. `bind-address` 配置错误
2. MySQL 没有监听外部连接
3. 防火墙或安全组阻止连接
4. MySQL 配置文件格式错误

***

## 🚀 快速排查步骤

### 1️⃣ **检查 MySQL 绑定地址**

```bash
# 查看当前配置
sudo grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf

# 或者查看所有配置
sudo cat /etc/mysql/mysql.conf.d/mysqld.cnf | grep -A 5 -B 5 bind-address
```

**正确配置**：
```ini
[mysqld]
bind-address = 0.0.0.0
```

**错误配置**（会导致远程连接失败）：
```ini
bind-address = 127.0.0.1
bind-address = localhost
# bind-address 被注释掉了
```

---

### 2️⃣ **检查 MySQL 监听端口**

```bash
# 查看 MySQL 监听的端口
sudo netstat -tlnp | grep mysql

# 或者使用 ss
sudo ss -tlnp | grep 3306
```

**正常输出**：
```
tcp6 0 0 :::3306 :::* LISTEN 3874/mysqld
```

**错误输出**（只监听本地）：
```
tcp6 0 0 127.0.0.1:3306 :::* LISTEN 3874/mysqld
```

---

### 3️⃣ **检查 MySQL 错误日志**

```bash
# 查看 MySQL 错误日志
sudo tail -n 50 /var/log/mysql/error.log

# 或者查看最近的错误
sudo grep -i "error\|warn" /var/log/mysql/error.log | tail -n 20
```

**常见错误**：
```
[ERROR] Can't start server: Bind on TCP/IP port: Cannot assign requested address
[ERROR] Do you already have another mysqld server running on port: 3306 ?
```

---

### 4️⃣ **检查防火墙设置**

```bash
# 查看防火墙状态
sudo ufw status

# 查看 3306 端口是否开放
sudo ufw status | grep 3306
```

**正常输出**：
```
3306                     ALLOW       Anywhere
3306 (v6)                ALLOW       Anywhere (v6)
```

---

### 5️⃣ **检查云服务商安全组**

登录阿里云/腾讯云控制台，检查安全组规则：

**入方向规则**：
- 端口范围: `3306`
- 协议: `TCP`
- 授权对象: `0.0.0.0/0`（测试）或 `10.0.0.0/8`（生产）

---

## 🔧 修复步骤

### 步骤 1: 修改 MySQL 配置

```bash
# 编辑配置文件
sudo vim /etc/mysql/mysql.conf.d/mysqld.cnf
```

找到 `bind-address`，修改为：

```ini
[mysqld]
# 允许所有IP连接（测试环境）
bind-address = 0.0.0.0

# 或者只允许特定IP（生产环境推荐）
# bind-address = 192.168.1.100
```

**注意**：
- 确保 `bind-address` 前面没有 `#` 注释符号
- 确保配置在 `[mysqld]` 部分下
- 确保缩进正确（不要有多余的空格）

---

### 步骤 2: 重启 MySQL

```bash
# 重启 MySQL 服务
sudo systemctl restart mysql

# 检查状态
sudo systemctl status mysql
```

**正常输出**：
```
● mysql.service - MySQL Community Server
     Active: active (running) since ...
     Main PID: XXXX (mysqld)
      Status: "Server is operational"
```

---

### 步骤 3: 验证监听端口

```bash
# 查看 MySQL 监听端口
sudo netstat -tlnp | grep mysql
```

**正确输出**：
```
tcp        0      0 0.0.0.0:3306            0.0.0.0:*               LISTEN      3874/mysqld
tcp        0      0 0.0.0.0:33060           0.0.0.0:*               LISTEN      3874/mysqld
```

**错误输出**（只监听本地）：
```
tcp        0      0 127.0.0.1:3306          0.0.0.0:*               LISTEN      3874/mysqld
```

---

### 步骤 4: 配置防火墙

```bash
# 允许所有 IP 访问（仅测试）
sudo ufw allow 3306

# 或者只允许特定 IP（推荐）
sudo ufw allow from 8.134.166.69 to any port 3306

# 重启防火墙
sudo ufw reload

# 查看状态
sudo ufw status verbose
```

**正常输出**：
```
3306                     ALLOW       Anywhere
3306 (v6)                ALLOW       Anywhere (v6)
```

---

### 步骤 5: 配置云服务商安全组

在阿里云/腾讯云控制台添加入方向规则：

| 端口范围 | 协议 | 授权对象 | 说明 |
|---------|------|---------|------|
| 3306 | TCP | 0.0.0.0/0 | 允许所有 IP（测试） |
| 3306 | TCP | 10.0.0.0/8 | 内网IP段（生产） |

---

### 步骤 6: 创建远程用户

```bash
# 登录 MySQL
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

### 步骤 7: 测试连接

```bash
# 从本地测试
mysql -u iot_user -p -h 127.0.0.1

# 从远程测试
mysql -u iot_user -p -h 8.134.166.69
```

---

## 📋 配置检查清单

- [x] `bind-address = 0.0.0.0`（或特定IP）
- [x] MySQL 服务已重启
- [x] MySQL 监听 `0.0.0.0:3306`（不是 `127.0.0.1:3306`）
- [ ] 防火墙允许 3306 端口
- [ ] 云服务商安全组允许 3306 端口
- [ ] 远程用户已创建
- [ ] 远程连接测试成功

---

## 🎯 快速修复命令

```bash
# 1. 检查配置
sudo grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf

# 2. 修改配置（如果配置错误）
sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

# 3. 重启 MySQL
sudo systemctl restart mysql

# 4. 验证监听端口
sudo netstat -tlnp | grep mysql

# 5. 配置防火墙
sudo ufw allow 3306
sudo ufw reload

# 6. 创建远程用户
sudo mysql -u root -p -e "CREATE USER 'iot_user'@'%' IDENTIFIED BY 'Iot2026.'; GRANT ALL PRIVILEGES ON hotel_system.* TO 'iot_user'@'%'; FLUSH PRIVILEGES;"

# 7. 测试连接
mysql -u iot_user -p -h 8.134.166.69
```

---

## 📚 参考资料

- [MySQL 官方文档](https://dev.mysql.com/doc/)
- [Ubuntu MySQL 文档](https://help.ubuntu.com/community/MySQL)
- [阿里云 MySQL 安全配置](https://help.aliyun.com/product/28146.html)

***

**最后更新**: 2026-04-07
