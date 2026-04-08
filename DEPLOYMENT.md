# 智慧酒店物联网控制系统 - 完整部署文档

## 📋 目录

1. [项目概述](#项目概述)
2. [环境准备](#环境准备)
3. [本地开发部署](#本地开发部署)
4. [Docker部署](#docker部署)
5. [生产环境部署](#生产环境部署)
6. [常见问题](#常见问题)

## 项目概述

智慧酒店物联网控制系统是一个基于物联网技术的酒店管理平台，实现了酒店前台管理、楼层控制和客房端的三-tier架构，支持云协同工作。

### 技术栈

- **后端**: Node.js + Express + TypeScript
- **数据库**: MySQL 8.0
- **缓存**: Redis 7.x
- **物联网通信**: MQTT
- **实时通信**: WebSocket
- **容器化**: Docker + Docker Compose

## 环境准备

### 1. 系统要求

- 操作系统: Windows 10/11, macOS 10.15+, Linux (Ubuntu 20.04+)
- 内存: 4GB 或更高
- 磁盘: 20GB 或更高

### 2. 软件要求

- Node.js 20.x 或更高版本
- MySQL 8.0 或更高版本
- Redis 7.x 或更高版本
- Docker 24.x 或更高版本 (可选)

### 3. 检查环境

```bash
# 检查Node.js版本
node --version

# 检查npm版本
npm --version

# 检查MySQL版本
mysql --version

# 检查Redis版本
redis-cli --version

# 检查Docker版本
docker --version
```

## 本地开发部署

### 1. 克隆项目

```bash
git clone https://github.com/your-username/iot-smart-hotel.git
cd iot-smart-hotel
```

### 2. 安装依赖

```bash
cd backend/iot-hotel-backend
npm install
```

### 3. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env` 文件：

```env
# 服务器配置
APP_HOST=localhost
APP_PORT=3000
NODE_ENV=development
API_PREFIX=/api/v1

# 数据库配置
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=iot_hotel_system

# Redis配置
REDIS_URL=redis://localhost:6379

# MQTT配置
MQTT_HOST=localhost
MQTT_PORT=1883
MQTT_USERNAME=
MQTT_PASSWORD=

# JWT配置
JWT_SECRET=iot_hotel_system_jwt_secret_2024
JWT_EXPIRES_IN=24h

# 日志配置
LOG_LEVEL=info
LOG_DIR=./logs
```

### 4. 初始化数据库

#### 方式一：使用Docker

```bash
cd ../docker
docker-compose up -d
```

#### 方式二：手动初始化

```bash
# 连接到MySQL
mysql -u root -p

# 执行初始化脚本
source /path/to/schema.sql
```

### 5. 启动服务器

```bash
cd backend/iot-hotel-backend
npm run dev
```

服务器将在 `http://localhost:3000` 启动。

### 6. 测试API

```bash
curl http://localhost:3000/api/v1/health
```

预期响应：

```json
{
  "code": 200,
  "message": "服务正常",
  "timestamp": 1712236800000,
  "version": "2.0.0"
}
```

## Docker部署

### 1. 克隆项目

```bash
git clone https://github.com/your-username/iot-smart-hotel.git
cd iot-smart-hotel
```

### 2. 启动所有服务

```bash
cd docker
docker-compose up -d
```

### 3. 查看服务状态

```bash
docker-compose ps
```

### 4. 查看日志

```bash
# 所有服务日志
docker-compose logs -f

# 单个服务日志
docker-compose logs -f backend
docker-compose logs -f mysql
docker-compose logs -f redis
docker-compose logs -f mqtt
```

### 5. 停止服务

```bash
docker-compose down
```

### 6. 重启服务

```bash
docker-compose restart
```

## 生产环境部署

### 1. 准备生产环境

#### 硬件要求

- 操作系统: Ubuntu 20.04 LTS 或更高
- CPU: 4核或更高
- 内存: 8GB或更高
- 磁盘: 50GB或更高
- 网络: 100Mbps或更高

#### 软件要求

- Node.js 20.x
- MySQL 8.0
- Redis 7.x
- Nginx (可选)
- PM2 (可选)

### 2. 配置生产环境变量

```bash
cd backend/iot-hotel-backend
cp .env.example .env
```

编辑 `.env` 文件：

```env
# 服务器配置
APP_HOST=0.0.0.0
APP_PORT=3000
NODE_ENV=production
API_PREFIX=/api/v1

# 数据库配置
DB_HOST=your-mysql-host
DB_PORT=3306
DB_USER=iot_user
DB_PASSWORD=your_strong_password
DB_NAME=iot_hotel_system

# Redis配置
REDIS_URL=redis://your-redis-host:6379

# MQTT配置
MQTT_HOST=your-mqtt-host
MQTT_PORT=1883
MQTT_USERNAME=your_username
MQTT_PASSWORD=your_password

# JWT配置
JWT_SECRET=your_strong_jwt_secret_key_here
JWT_EXPIRES_IN=24h

# 日志配置
LOG_LEVEL=info
LOG_DIR=./logs
```

### 3. 构建生产版本

```bash
npm run build
```

### 4. 启动生产服务器

#### 方式一：直接启动

```bash
npm start
```

#### 方式二：使用PM2

```bash
npm install -g pm2
pm2 start dist/server.js --name iot-hotel-backend
pm2 save
pm2 startup
```

### 5. 配置Nginx (可选)

创建Nginx配置文件 `/etc/nginx/sites-available/iot-hotel-backend`：

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location /api/v1 {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

启用配置：

```bash
sudo ln -s /etc/nginx/sites-available/iot-hotel-backend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## 常见问题

### 1. 端口被占用

```bash
# Windows
netstat -ano | findstr :3000
taskkill /PID <PID> /F

# Linux/Mac
lsof -i :3000
kill -9 <PID>
```

### 2. 数据库连接失败

```bash
# 检查MySQL服务状态
systemctl status mysql

# 检查数据库配置
cat .env

# 测试数据库连接
mysql -u root -p -h localhost -P 3306
```

### 3. Redis连接失败

```bash
# 检查Redis服务状态
systemctl status redis

# 测试Redis连接
redis-cli ping
```

### 4. MQTT连接失败

```bash
# 检查MQTT服务状态
systemctl status mosquitto

# 测试MQTT连接
mosquitto_sub -h localhost -p 1883 -t "test"
```

### 5. 依赖安装失败

```bash
# 清除缓存
npm cache clean --force

# 重新安装
npm install
```

### 6. TypeScript编译错误

```bash
# 清除编译缓存
npm run clean

# 重新编译
npm run build
```

## 🔐 安全建议

### 1. 数据库安全

- 使用强密码
- 限制数据库用户权限
- 启用SSL连接
- 定期备份数据库

### 2. 应用安全

- 使用HTTPS
- 启用CORS限制
- 配置防火墙
- 定期更新依赖

### 3. 系统安全

- 启用防火墙
- 定期更新系统
- 限制SSH访问
- 启用日志审计

## 📊 监控与日志

### 1. 查看应用日志

```bash
# 开发模式
npm run dev

# 生产模式
cat logs/app.log
```

### 2. 查看错误日志

```bash
cat logs/error.log
```

### 3. 查看系统日志

```bash
# Linux
journalctl -u iot-hotel-backend

# Docker
docker-compose logs -f backend
```

## 🔄 备份与恢复

### 1. 数据库备份

```bash
# 使用mysqldump
mysqldump -u root -p iot_hotel_system > backup.sql

# 使用Docker
docker-compose exec mysql mysqldump -u root -p iot_hotel_system > backup.sql
```

### 2. 数据库恢复

```bash
# 使用mysql
mysql -u root -p iot_hotel_system < backup.sql

# 使用Docker
docker-compose exec mysql mysql -u root -p iot_hotel_system < backup.sql
```

## 📚 相关文档

- [项目结构说明](./docs/项目结构说明.md)
- [数据库配置说明](./docs/数据库配置说明.md)
- [启动指南](./docs/启动指南.md)
- [完整部署指南](./docs/完整部署指南.md)
- [Docker配置说明](./docs/Docker配置说明.md)

***

**版本**: v1.0.0\
**最后更新**: 2026年4月4日
