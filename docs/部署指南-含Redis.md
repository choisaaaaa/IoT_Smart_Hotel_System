# 🚀 IoT智慧酒店系统 - 服务器部署指南（含Redis）

## 📋 目录
- [环境要求](#环境要求)
- [一、服务器基础配置](#一服务器基础配置)
- [二、安装Redis](#二安装redis)
- [三、安装Node.js](#三安装nodejs)
- [四、安装MySQL](#四安装mysql)
- [五、安装MQTT (Mosquitto)](#五安装mqtt-mosquitto)
- [六、部署后端服务](#六部署后端服务)
- [七、部署前端](#七部署前端)
- [八、Nginx反向代理配置](#八nginx反向代理配置)
- [九、系统服务配置（PM2）](#九系统服务配置pm2)
- [十、防火墙与安全配置](#十防火墙与安全配置)
- [十一、监控与维护](#十一监控与维护)

---

## 环境要求

| 组件 | 版本要求 | 用途 |
|------|---------|------|
| **操作系统** | Ubuntu 20.04+ / CentOS 8+ | 服务器系统 |
| **Redis** | 6.x / 7.x | 缓存层 |
| **Node.js** | 18.x LTS | 后端运行时 |
| **MySQL** | 8.0 | 数据库 |
| **Mosquitto** | 2.x | MQTT消息代理 |
| **Nginx** | 1.18+ | 反向代理 |
| **PM2** | 5.x | 进程管理 |
| **Git** | 最新版 | 代码拉取 |

---

## 一、服务器基础配置

### 1.1 更新系统包

```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
```

### 1.2 创建应用用户（可选但推荐）

```bash
# 创建专用用户运行应用
sudo useradd -m -s /bin/bash iot-hotel
sudo su - iot-hotel
```

### 1.3 安装常用工具

```bash
# Ubuntu/Debian
sudo apt install -y curl wget git unzip build-essential software-properties-common

# CentOS/RHEL
sudo yum install -y curl wget git unzip gcc-c++ make epel-release
```

---

## 二、安装Redis

### 2.1 使用包管理器安装（推荐）

```bash
# Ubuntu/Debian
sudo apt install -y redis-server

# CentOS/RHEL
sudo yum install -y redis
```

### 2.2 或使用源码编译安装（获取最新版本）

```bash
# 下载并编译Redis 7.x
cd /usr/local/src
wget https://download.redis.io/redis-stable.tar.gz
tar xzf redis-stable.tar.gz
cd redis-stable
make
sudo make install

# 创建配置目录
sudo mkdir -p /etc/redis
sudo cp redis.conf /etc/redis/
```

### 2.3 配置Redis

编辑 `/etc/redis/redis.conf`：

```bash
sudo nano /etc/redis/redis.conf
```

**关键配置项：**

```conf
# 绑定地址（如果仅本地访问，保持127.0.0.1）
bind 127.0.0.1

# 监听端口
port 6379

# 设置密码（生产环境必须）
requirepass YOUR_STRONG_PASSWORD_HERE

# 持久化配置
save 900 1
save 300 10
save 60 10000

# AOF持久化（推荐）
appendonly yes
appendfsync everysec

# 内存限制（根据服务器内存调整，建议不超过物理内存的50%）
maxmemory 512mb
maxmemory-policy allkeys-lru

# 日志配置
loglevel notice
logfile /var/log/redis/redis-server.log

# 最大连接数
maxclients 10000
```

### 2.4 创建日志目录并启动

```bash
sudo mkdir -p /var/log/redis
sudo chown redis:redis /var/log/redis

# 启动Redis服务
sudo systemctl start redis-server
sudo systemctl enable redis-server

# 验证运行状态
sudo systemctl status redis-server
redis-cli ping  # 应返回 PONG
```

### 2.5 验证密码认证

```bash
redis-cli -a YOUR_PASSWORD ping
```

---

## 三、安装Node.js

### 3.1 使用nvm安装（推荐）

```bash
# 安装nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# 重新加载shell或执行：
source ~/.bashrc

# 安装Node.js 18 LTS
nvm install 18
nvm use 18
nvm alias default 18

# 验证安装
node -v   # v18.x.x
npm -v    # 9.x.x
```

### 3.2 或直接安装Node.js

```bash
# Ubuntu/Debian - 使用NodeSource
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# CentOS/RHEL
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs
```

### 3.3 全局安装PM2（进程管理器）

```bash
sudo npm install -g pm2

# 设置PM2开机自启
pm2 startup
# 执行输出的命令（通常类似：sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u iot-hotel --hp /home/iot-hotel）
pm2 save
```

---

## 四、安装MySQL

### 4.1 安装MySQL服务器

```bash
# Ubuntu/Debian
sudo apt install -y mysql-server mysql-client

# CentOS/RHEL
sudo yum install -y mysql-server mysql
sudo systemctl start mysqld
sudo systemctl enable mysqld
```

### 4.2 安全初始化

```bash
sudo mysql_secure_installation
```

按照提示：
- 设置root密码
- 移除匿名用户
- 禁止root远程登录
- 删除测试数据库

### 4.3 创建数据库和用户

```bash
mysql -u root -p
```

```sql
-- 创建数据库
CREATE DATABASE iot_hotel_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建专用用户（不要用root）
CREATE USER 'iot_hotel'@'localhost' IDENTIFIED BY 'YOUR_DB_PASSWORD';
GRANT ALL PRIVILEGES ON iot_hotel_system.* TO 'iot_hotel'@'localhost';
FLUSH PRIVILEGES;

-- 如果后端不在本机，允许远程连接（谨慎使用）
-- CREATE USER 'iot_hotel'@'%' IDENTIFIED BY 'YOUR_DB_PASSWORD';
-- GRANT ALL PRIVILEGES ON iot_hotel_system.* TO 'iot_hotel'@'%';
-- FLUSH PRIVILEGES;
EXIT;
```

### 4.4 导入数据库结构

```bash
# 从项目目录导入初始SQL
mysql -u root -p iot_hotel_system < database/init.sql
# 或者如果有完整的初始化脚本
mysql -u root -p iot_hotel_system < docker/mysql/init/full_init.sql
```

---

## 五、安装MQTT (Mosquitto)

### 5.1 安装Mosquitto

```bash
# Ubuntu/Debian
sudo apt install -y mosquitto mosquitto-clients

# CentOS/RHEL
sudo yum install -y epel-release
sudo yum install -y mosquitto mosquitto-clients
```

### 5.2 配置Mosquitto

编辑 `/etc/mosquitto/mosquitto.conf`：

```conf
# 监听端口
listener 1883
allow_anonymous false
password_file /etc/mosquitto/passwd

# WebSocket支持（前端可能用到）
listener 9001
protocol websockets
```

### 5.3 设置MQTT用户名密码

```bash
# 创建用户文件
sudo touch /etc/mosquitto/passwd
sudo mosquitto_passwd -b /etc/mosquitto/passwd mqtt_user MQTT_PASSWORD

# 重启服务
sudo systemctl restart mosquitto
sudo systemctl enable mosquitto
```

### 5.4 验证MQTT

```bash
# 订阅测试（新终端窗口1）
mosquitto_sub -h localhost -p 1883 -u mqtt_user -P MQTT_PASSWORD -t "test/#"

# 发布测试（新终端窗口2）
mosquitto_pub -h localhost -p 1883 -u mqtt_user -P MQTT_PASSWORD -t "test/hello" -m "Hello MQTT"
```

---

## 六、部署后端服务

### 6.1 克隆代码（或上传代码）

```bash
# 方式1: Git克隆
cd /opt
sudo mkdir -p iot-hotel
sudo chown $USER:$USER iot-hotel
cd iot-hotel
git clone <your-repo-url> backend

# 方式2: 上传压缩包
scp -r backend/ user@server:/opt/iot-hotel/backend/
```

### 6.2 安装依赖

```bash
cd /opt/iot-hotel-backend
npm install --production
```

### 6.3 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑配置
nano .env
```

**关键配置项：**

```env
# =============================================================================
# 基础服务配置
# =============================================================================
NODE_ENV=production
APP_HOST=0.0.0.0
APP_PORT=3000

# =============================================================================
# 数据库配置
# =============================================================================
DB_HOST=localhost
DB_PORT=3306
DB_USER=iot_hotel
DB_PASSWORD=YOUR_DB_PASSWORD
DB_NAME=iot_hotel_system

# =============================================================================
# Redis缓存配置（新增）
# =============================================================================
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=YOUR_REDIS_PASSWORD
REDIS_DB=0
REDIS_KEY_PREFIX=iot_hotel:
CACHE_ENABLED=true
CACHE_DEFAULT_TTL=300

# =============================================================================
# JWT密钥（必须修改为强随机字符串）
# =============================================================================
JWT_SECRET=$(openssl rand -base64 32)
JWT_EXPIRES_IN=24h

# =============================================================================
# MQTT配置
# =============================================================================
MQTT_HOST=mqtt://127.0.0.1
MQTT_PORT=1883
MQTT_USERNAME=mqtt_user
MQTT_PASSWORD=MQTT_PASSWORD

# =============================================================================
# AI配置（可选）
# =============================================================================
ZHIPU_AI_API_KEY=your_api_key_here

# =============================================================================
# 文件上传配置
# =============================================================================
UPLOAD_PATH=uploads
UPLOAD_PUBLIC_URL=https://your-domain.com/uploads
```

### 6.4 构建项目

```bash
npm run build
```

### 6.5 使用PM2启动服务

```bash
# 启动应用
pm2 start dist/server.js --name "iot-hotel-backend" \
  --node-args="--max-old-space-size=512"

# 或者使用ecosystem配置文件
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'iot-hotel-backend',
    script: 'dist/server.js',
    instances: 2,          // 根据CPU核心数调整
    exec_mode: 'cluster', // cluster模式提高稳定性
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_log: './logs/error.log',
    out_log: './logs/out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss'
  }]
};
EOF

pm2 start ecosystem.config.js
pm2 save
```

### 6.6 验证后端运行

```bash
# 查看进程状态
pm2 status

# 查看日志
pm2 logs iot-hotel-backend --lines 50

# 测试API
curl http://localhost:3000/health
# 应返回: {"code":200,"message":"...","timestamp":...,"version":"2.2.0"}
```

---

## 七、部署前端

### 7.1 构建前端

在开发机器上：

```bash
cd frontend/iot-hotel-web
npm install
npm run build
```

### 7.2 上传构建产物到服务器

```bash
# 将dist目录上传到服务器
scp -r dist/* user@server:/var/www/iot-hotel/

# 或使用rsync同步
rsync -avz dist/ user@server:/var/www/iot-hotel/
```

### 7.3 服务器端准备静态目录

```bash
sudo mkdir -p /var/www/iot-hotel
sudo chown -R www-data:www-data /var/www/iot-hotel
```

---

## 八、Nginx反向代理配置

### 8.1 安装Nginx

```bash
# Ubuntu/Debian
sudo apt install -y nginx

# CentOS/RHEL
sudo yum install -y epel-release
sudo yum install -y nginx
```

### 8.2 配置站点

创建 `/etc/nginx/sites-available/iot-hotel.conf`：

```nginx
server {
    listen 80;
    server_name your-domain.com;  # 替换为你的域名或IP
    
    # 前端静态资源
    location / {
        root /var/www/iot-hotel;
        index index.html;
        try_files $uri $uri/ /index.html;  # Vue Router history模式支持
        
        # 静态资源缓存
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 30d;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # API代理到后端
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # 文件上传大小限制
    client_max_body_size 50M;
    
    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;
}
```

### 8.3 启用配置

```bash
# 创建软链接启用站点
sudo ln -s /etc/nginx/sites-available/iot-hotel.conf /etc/nginx/sites-enabled/

# 删除默认站点（可选）
sudo rm /etc/nginx/sites-enabled/default

# 测试配置语法
sudo nginx -t

# 重载Nginx
sudo systemctl reload nginx
sudo systemctl enable nginx
```

### 8.4 HTTPS配置（生产环境强烈推荐）

```bash
# 安装Certbot获取Let's Encrypt免费证书
sudo apt install -y certbot python3-certbot-nginx

# 获取证书并自动配置
sudo certbot --nginx -d your-domain.com

# 自动续期（已自动配置）
sudo certbot renew --dry-run
```

---

## 九、系统服务配置（PM2）

### 9.1 PM2开机自启

```bash
# 生成启动脚本
pm2 startup

# 保存当前进程列表
pm2 save
```

### 9.2 PM2常用命令

```bash
# 查看所有进程
pm2 status

# 查看某个进程详情
pm2 show iot-hotel-backend

# 查看实时日志
pm2 logs iot-hotel-backend

# 重启服务
pm2 restart iot-hotel-backend

# 停止服务
pm2 stop iot-hotel-backend

# 删除服务
pm2 delete iot-hotel-backend

# 监控面板
pm2 monit
```

### 9.3 日志管理

```bash
# PM2日志轮转
pm2 install pm2-logrotate

# 或手动配置logrotate
sudo tee /etc/logrotate.d/iot-hotel << 'EOF'
/opt/iot-hotel-backend/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 iot-hotel iot-hotel
    postrotate
        pm2 reloadLogs > /dev/null 2>&1 || true
    endscript
}
EOF
```

---

## 十、防火墙与安全配置

### 10.1 UFW防火墙（Ubuntu）

```bash
# 启用UFW
sudo ufw enable

# 允许SSH
sudo ufw allow 22/tcp

# 允许HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Redis仅限本地访问（默认已限制）
# 不需要开放6379端口

# MQTT如需外部访问（不推荐）
# sudo ufw allow 1883/tcp

# 查看规则
sudo ufw status verbose
```

### 10.2 Firewalld（CentOS）

```bash
# 开启防火墙
sudo systemctl enable --now firewalld

# 开放必要端口
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# 重载规则
sudo firewall-cmd --reload

# 查看规则
sudo firewall-cmd --list-all
```

### 10.3 SSH安全加固

编辑 `/etc/ssh/sshd_config`：

```conf
# 禁止root登录
PermitRootLogin no

# 禁止空密码登录
PermitEmptyPasswords no

# 仅允许密钥登录（可选，先确保你有密钥登录方式）
# PasswordAuthentication no

# 更改默认端口（可选）
Port 2222
```

重启SSH：
```bash
sudo systemctl restart sshd
```

### 10.4 fail2ban防暴力破解

```bash
# 安装fail2ban
sudo apt install -y fail2ban

# 创建本地配置
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```

添加以下内容：

```ini
[sshd]
enabled = true
port = ssh,2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime = 3600

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 5
findtime = 600
bantime = 3600
```

启动fail2ban：
```bash
sudo systemctl enable --now fail2ban
```

---

## 十一、监控与维护

### 11.1 Redis监控命令

```bash
# 连接Redis
redis-cli -a YOUR_PASSWORD

# 查看信息
INFO server
INFO memory
INFO stats

# 查看缓存键数量
DBSIZE

# 查看特定前缀的键数
KEYS iot_hotel:*

# 查看键的TTL
TTL iot_hotel:hotel:list

# 实时监控
MONITOR

# 慢查询日志（需提前配置）
SLOWLOG GET 10
```

### 11.2 系统监控脚本

创建 `/opt/scripts/monitor.sh`：

```bash
#!/bin/bash
# IoT智慧酒店系统健康检查脚本

echo "========================================="
echo "IoT智慧酒店系统状态检查"
echo "时间: $(date)"
echo "========================================="

# 1. Redis状态
echo ""
echo "[Redis]"
if redis-cli -a YOUR_PASSWORD ping > /dev/null 2>&1; then
    echo "✅ Redis运行正常"
    echo "   内存使用: $(redis-cli -a YOUR_PASSWORD INFO memory | grep used_memory_human | awk '{print $2}')"
    echo "   连接数: $(redis-cli -a YOUR_PASSWORD INFO clients | grep connected_clients | awk '{print $2}')"
else
    echo "❌ Redis未运行或无法连接"
fi

# 2. MySQL状态
echo ""
echo "[MySQL]"
if systemctl is-active --quiet mysql; then
    echo "✅ MySQL运行正常"
else
    echo "❌ MySQL未运行"
fi

# 3. Node.js/PM2状态
echo ""
echo "[Backend]"
if pm2 list | grep -q "iot-hotel"; then
    echo "✅ 后端服务运行正常"
    pm2 list | grep "iot-hotel"
else
    echo "❌ 后端服务未运行"
fi

# 4. Nginx状态
echo ""
echo "[Nginx]"
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx运行正常"
else
    echo "❌ Nginx未运行"
fi

# 5. Mosquitto状态
echo ""
echo "[MQTT]"
if systemctl is-active --quiet mosquitto; then
    echo "✅ MQTT服务运行正常"
else
    echo "❌ MQTT服务未运行"
fi

# 6. 磁盘空间
echo ""
echo "[磁盘空间]"
df -h / | tail -1 | awk '{printf "   总计:%s 已用:%s 可用:%s 使用率:%s\n", $2, $3, $4, $5}'

# 7. 内存使用
echo ""
echo "[内存使用]"
free -h | grep Mem | awk '{printf "   总计:%s 已用:%s 可用:%s 使用率:%.1f%%\n", $2, $3, $7, ($3/$2)*100}'

echo ""
echo "========================================="
echo "检查完成"
echo "========================================="
```

使用方法：
```bash
chmod +x /opt/scripts/monitor.sh
/opt/scripts/monitor.sh

# 可以加入crontab定时执行
crontab -e
# 添加：*/5 * * * * /opt/scripts/monitor.sh >> /var/log/system-monitor.log 2>&1
```

### 11.3 性能优化建议

#### Redis优化
```bash
# 在redis.conf中根据实际情况调整内存策略
# 内存不足时的淘汰策略：
# volatile-lru: 从设置了过期时间的key中淘汰最近最少使用的
# allkeys-lru: 从所有key中淘汰最近最少使用的（推荐用于纯缓存场景）
# volatile-ttl: 从设置了过期时间的key中淘汰即将过期的
# noeviction: 不淘汰，写入时报错（适合数据不能丢失的场景）
```

#### Node.js优化
```javascript
// 在ecosystem.config.js中配置
{
  max_memory_restart: '512M',  // 内存超过512MB自动重启
  instances: require('os').cpus().length,  // 根据CPU核心数开启多实例
  exec_mode: 'cluster'  // cluster模式
}
```

#### MySQL优化
```ini
# /etc/mysql/my.cnf 或 /etc/my.cnf.d/custom.cnf
[mysqld]
innodb_buffer_pool_size = 256M  # 物理内存的50%-70%
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2
max_connections = 200
query_cache_size = 64M
slow_query_log = 1
long_query_time = 2
```

---

## 📞 故障排查

### 常见问题及解决方案

| 问题 | 可能原因 | 解决方案 |
|------|---------|---------|
| Redis连接失败 | 服务未启动/密码错误/端口被占用 | `systemctl status redis`, 检查配置 |
| 后端启动失败 | 端口被占用/依赖缺失/环境变量错误 | `netstat -tlnp \| grep 3000`, 检查.env |
| API返回502 | 后端服务崩溃/Nginx配置错误 | `pm2 logs`, `nginx -t` |
| 缓存不生效 | CACHE_ENABLED=false/Redis未连接 | 检查.env和Redis状态 |
| 数据库连接失败 | 用户权限问题/网络不通 | `mysql -u user -p -h host`测试 |

### 快速诊断命令

```bash
# 一键检查所有服务状态
systemctl status redis mysql mosquitto nginx && pm2 status

# 检查端口监听
ss -tlnp | grep -E '3000|6379|3306|1883|80'

# 查看实时日志
tail -f /opt/iot-hotel-backend/logs/error.log

# Redis连通性测试
redis-cli -h 127.0.0.1 -p 6379 -a PASSWORD ping
```

---

## ✅ 部署检查清单

部署完成后，请逐项确认：

- [ ] 操作系统已更新至最新版本
- [ ] Redis已安装并配置密码
- [ ] MySQL已创建数据库和专用用户
- [ ] Node.js 18 LTS已安装
- [ ] PM2已安装并配置开机自启
- [ ] Mosquitto已安装并配置认证
- [ ] 后端代码已上传并npm install完成
- [ ] `.env`文件已正确配置（特别是数据库密码、Redis密码、JWT密钥）
- [ ] 后端服务通过PM2正常运行
- [ ] 前端已构建并部署到Nginx静态目录
- [ ] Nginx已配置反向代理并重载
- [ ] 防火墙已配置（仅开放必要端口）
- [ ] SSH已加固（禁止root登录等）
- [ ] fail2ban已安装并启用
- [ ] 所有服务已设置为开机自启
- [ ] 已测试API接口可正常访问
- [ ] 已配置HTTPS（生产环境）
- [ ] 已设置定期备份策略

---

## 📝 备份策略建议

### 自动备份脚本 `/opt/scripts/backup.sh`

```bash
#!/bin/bash
BACKUP_DIR="/backup/iot-hotel"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR/{mysql,redis,code}

# 备份MySQL
mysqldump -u root -pPASSWORD iot_hotel_system | gzip > $BACKUP_DIR/mysql/db_$DATE.sql.gz

# 备份Redis RDB文件
cp /var/lib/redis/dump.rdb $BACKUP_DIR/redis/dump_$DATE.rdb

# 清理7天前的备份
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.rdb" -mtime +7 -delete

echo "备份完成: $DATE"
```

定时任务：
```bash
# 每天凌晨3点执行备份
crontab -e
0 3 * * * /opt/scripts/backup.sh >> /var/log/backup.log 2>&1
```

---

**部署完成后，记得保存好所有密码和配置信息的安全副本！** 🔐
