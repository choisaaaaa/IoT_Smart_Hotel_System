# 智慧酒店物联网控制系统 - Docker部署指南

## 🐳 Docker部署

本项目支持使用Docker进行快速部署，包括Nginx反向代理、MySQL、Redis、MQTT、后端服务和前端静态资源。

## 📦 容器架构

```
docker-compose
├── nginx          # Nginx反向代理 (端口80/443)
├── backend        # Node.js后端服务 (端口3000)
├── mysql          # MySQL数据库 (端口3306)
├── redis          # Redis缓存 (端口6379)
└── mqtt           # Mosquitto MQTT Broker (端口1883/9001)
```

## 📁 目录结构

```
docker/
├── docker-compose.yml          # Docker Compose配置
├── nginx/
│   ├── nginx.conf             # Nginx主配置
│   └── conf.d/
│       └── default.conf       # 站点配置
├── mysql/
│   └── init/
│       └── schema.sql         # 数据库初始化脚本
├── redis/
│   └── redis.conf             # Redis配置
├── mqtt/
│   └── mosquitto.conf         # MQTT配置
└── README.md                  # 本文件
```

## 🚀 快速部署

### 1. 前置条件

- Docker >= 20.10
- Docker Compose >= 1.29
- Node.js >= 18 (用于构建前端)

### 2. 构建前端静态资源

```bash
cd ../frontend/iot-hotel-web
npm install
npm run build
```

### 3. 启动所有服务

```bash
cd docker
docker-compose up -d
```

### 4. 查看服务状态

```bash
docker-compose ps
```

输出示例：
```
NAME                IMAGE                    PORTS
iot-hotel-nginx     nginx:alpine             0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
iot-hotel-backend   iot-hotel-backend        0.0.0.0:3000->3000/tcp
iot-hotel-mysql     mysql:8.0                0.0.0.0:3306->3306/tcp
iot-hotel-redis     redis:7-alpine           0.0.0.0:6379->6379/tcp
iot-hotel-mqtt      eclipse-mosquitto:2.0    0.0.0.0:1883->1883/tcp, 0.0.0.0:9001->9001/tcp
```

### 5. 查看日志

```bash
# 所有服务日志
docker-compose logs -f

# 单个服务日志
docker-compose logs -f nginx
docker-compose logs -f backend
docker-compose logs -f mysql
docker-compose logs -f redis
docker-compose logs -f mqtt
```

### 6. 停止服务

```bash
docker-compose down
```

### 7. 重启服务

```bash
docker-compose restart
```

## 📊 访问服务

### Web应用 (Nginx)

```
http://localhost
```

### 后端API (通过Nginx代理)

```
http://localhost/api/v1/health
```

### 后端API (直接访问)

```
http://localhost:3000/api/v1/health
```

### 数据库连接

```
Host: localhost
Port: 3306
Database: iot_hotel_system
User: iot_user
Password: iot_password
```

### Redis连接

```
Host: localhost
Port: 6379
Database: 0
```

### MQTT连接

```
Host: localhost
Port: 1883
WebSocket Port: 9001
```

## 🔧 配置说明

### 1. Nginx配置

- **镜像**: nginx:alpine
- **端口**: 80 (HTTP), 443 (HTTPS)
- **功能**: 
  - 静态资源服务 (前端dist目录)
  - API反向代理 (/api/ -> backend:3000)
  - WebSocket代理 (/socket.io/)
  - Gzip压缩
  - 静态资源缓存

### 2. 后端服务配置

- **构建**: 基于 backend/iot-hotel-backend/Dockerfile
- **端口**: 3000
- **环境变量**:
  - `NODE_ENV`: development/production
  - `DB_HOST`: mysql (容器名)
  - `DB_PORT`: 3306
  - `REDIS_HOST`: redis (容器名)
  - `REDIS_PORT`: 6379
  - `MQTT_HOST`: mqtt (容器名)
  - `MQTT_PORT`: 1883
  - `JWT_SECRET`: JWT密钥
  - `API_PREFIX`: /api/v1

### 3. MySQL配置

- **镜像**: mysql:8.0
- **端口**: 3306
- **数据库**: iot_hotel_system
- **用户名**: iot_user
- **密码**: iot_password
- **初始化**: 自动执行 mysql/init/*.sql

### 4. Redis配置

- **镜像**: redis:7-alpine
- **端口**: 6379
- **持久化**: RDB + AOF
- **数据库**: 16个 (默认使用db 0)
- **配置**: 通过 redis/redis.conf 自定义

### 5. MQTT配置

- **镜像**: eclipse-mosquitto:2.0
- **端口**: 1883 (MQTT), 9001 (WebSocket)
- **匿名访问**: 允许 (开发环境)

## 🔧 开发模式

### 1. 启动基础设施服务

```bash
cd docker
docker-compose up -d mysql redis mqtt
```

### 2. 本地开发后端

```bash
cd ../backend/iot-hotel-backend
npm install
npm run dev
```

### 3. 本地开发前端

```bash
cd ../frontend/iot-hotel-web
npm install
npm run dev
```

### 4. 进入容器调试

```bash
# 进入Nginx容器
docker-compose exec nginx sh

# 进入后端容器
docker-compose exec backend sh

# 进入MySQL容器
docker-compose exec mysql bash

# 进入Redis容器
docker-compose exec redis sh

# 进入MQTT容器
docker-compose exec mqtt sh
```

### 5. Redis命令行

```bash
docker-compose exec redis redis-cli

# 查看所有键
KEYS *

# 查看键值
GET key_name

# 删除键
DEL key_name

# 清空数据库
FLUSHDB
```

### 6. MySQL命令行

```bash
docker-compose exec mysql mysql -u iot_user -piot_password iot_hotel_system

# 查看所有表
SHOW TABLES;

# 查看表结构
DESCRIBE table_name;
```

## 🐳 单独部署

### 1. 启动Nginx

```bash
docker run -d \
  --name iot-nginx \
  -p 80:80 \
  -p 443:443 \
  -v $(pwd)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v $(pwd)/nginx/conf.d:/etc/nginx/conf.d:ro \
  -v $(pwd)/../frontend/iot-hotel-web/dist:/usr/share/nginx/html:ro \
  nginx:alpine
```

### 2. 启动MySQL

```bash
docker run -d \
  --name iot-mysql \
  -e MYSQL_ROOT_PASSWORD=root_password \
  -e MYSQL_DATABASE=iot_hotel_system \
  -e MYSQL_USER=iot_user \
  -e MYSQL_PASSWORD=iot_password \
  -p 3306:3306 \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0
```

### 3. 启动Redis

```bash
docker run -d \
  --name iot-redis \
  -p 6379:6379 \
  -v redis-data:/data \
  redis:7-alpine \
  redis-server --appendonly yes
```

### 4. 启动MQTT

```bash
docker run -d \
  --name iot-mqtt \
  -p 1883:1883 \
  -p 9001:9001 \
  -v $(pwd)/mqtt/mosquitto.conf:/mosquitto/config/mosquitto.conf:ro \
  eclipse-mosquitto:2.0
```

### 5. 构建并启动后端

```bash
cd ../backend/iot-hotel-backend
docker build -t iot-hotel-backend .
docker run -d \
  --name iot-backend \
  -p 3000:3000 \
  --env-file .env \
  --link iot-mysql:mysql \
  --link iot-redis:redis \
  --link iot-mqtt:mqtt \
  iot-hotel-backend
```

## 📝 常见问题

### Q1: 端口冲突

```bash
# 查看端口占用
netstat -tlnp | grep 80

# 停止服务
docker-compose down

# 修改docker-compose.yml中的端口映射后重新启动
docker-compose up -d
```

### Q2: 数据库连接失败

```bash
# 检查MySQL容器状态
docker-compose ps mysql

# 查看MySQL日志
docker-compose logs mysql

# 重新初始化数据库
docker-compose down
docker volume rm docker_mysql-data
docker-compose up -d mysql
```

### Q3: 服务无法启动

```bash
# 查看服务日志
docker-compose logs backend

# 重新构建服务
docker-compose down
docker-compose up -d --build
```

### Q4: 前端页面404

```bash
# 确保前端已构建
cd ../frontend/iot-hotel-web
npm run build

# 重启Nginx
docker-compose restart nginx
```

### Q5: Redis连接失败

```bash
# 检查Redis容器状态
docker-compose ps redis

# 查看Redis日志
docker-compose logs redis

# 测试Redis连接
docker-compose exec redis redis-cli ping
```

## 🔐 安全加固

### 1. 修改默认密码

编辑 `docker-compose.yml` 文件：

```yaml
environment:
  - MYSQL_ROOT_PASSWORD=your_strong_root_password
  - MYSQL_PASSWORD=your_strong_password
  - REDIS_PASSWORD=your_redis_password
  - JWT_SECRET=your_jwt_secret_key
```

### 2. 配置Redis密码

编辑 `redis/redis.conf`：

```
requirepass your_redis_password
```

### 3. 禁用MQTT匿名访问

编辑 `mqtt/mosquitto.conf`：

```
allow_anonymous false
password_file /mosquitto/config/passwd
```

创建密码文件：

```bash
docker-compose exec mqtt mosquitto_passwd -c /mosquitto/config/passwd admin
```

### 4. 配置SSL证书

编辑 `nginx/conf.d/default.conf`，添加HTTPS配置：

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    # ... 其他配置
}
```

## 📊 监控与日志

### 1. 查看容器资源使用

```bash
docker stats
```

### 2. 查看容器详细信息

```bash
docker inspect iot-hotel-nginx
docker inspect iot-hotel-backend
docker inspect iot-hotel-mysql
docker inspect iot-hotel-redis
docker inspect iot-hotel-mqtt
```

### 3. 清理Docker资源

```bash
# 清理未使用的容器
docker container prune

# 清理未使用的镜像
docker image prune

# 清理未使用的卷
docker volume prune

# 清理所有未使用的资源
docker system prune -a
```

## 🔄 更新与升级

### 1. 更新镜像

```bash
docker-compose pull
docker-compose up -d
```

### 2. 重新构建

```bash
docker-compose down
docker-compose up -d --build
```

### 3. 数据库迁移

```bash
# 备份数据库
docker-compose exec mysql mysqldump -u iot_user -piot_password iot_hotel_system > backup.sql

# 执行迁移脚本
docker-compose exec mysql mysql -u iot_user -piot_password iot_hotel_system < migration.sql

# 恢复数据
docker-compose exec mysql mysql -u iot_user -piot_password iot_hotel_system < backup.sql
```

## 📈 性能优化

### 1. Nginx优化

- 启用Gzip压缩 (已配置)
- 静态资源缓存 (已配置)
- 调整worker_processes和worker_connections

### 2. MySQL优化

编辑 `docker-compose.yml`，添加性能参数：

```yaml
command: >
  --innodb-buffer-pool-size=512M
  --query-cache-size=64M
  --max-connections=200
```

### 3. Redis优化

编辑 `redis/redis.conf`：

```
maxmemory 256mb
maxmemory-policy allkeys-lru
```

### 4. Node.js优化

编辑 `backend/iot-hotel-backend/Dockerfile`，使用PM2：

```dockerfile
# 安装PM2
RUN npm install -g pm2

# 使用PM2启动
CMD ["pm2-runtime", "dist/server.js", "-i", "max"]
```

---

**版本**: v2.0.0  
**最后更新**: 2026年4月23日  
**更新内容**: 新增Nginx和Redis容器，完善容器架构
