# 智慧酒店物联网控制系统 - 部署指南 (Linux)

本指南以 **Ubuntu 22.04 LTS** 为例，涵盖从系统环境初始化到前后端服务上线的完整部署流程。

---

## 1. 系统环境初始化

### 更新系统包
```bash
sudo apt update && sudo apt upgrade -y
```

### 安装 Node.js (推荐 v20.x)
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

### 安装 MySQL 8.0
```bash
sudo apt install -y mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql
```

### 安装 MQTT Broker (Mosquitto)
```bash
sudo apt install -y mosquitto mosquitto-clients
sudo systemctl start mosquitto
sudo systemctl enable mosquitto
```

---

## 2. 数据库配置

1. **登录并创建数据库**：
   ```bash
   sudo mysql -u root
   ```
2. **执行初始化 SQL**：
   ```sql
   CREATE DATABASE iot_hotel_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'iot_user'@'localhost' IDENTIFIED BY '您的密码';
   GRANT ALL PRIVILEGES ON iot_hotel_system.* TO 'iot_user'@'localhost';
   FLUSH PRIVILEGES;
   EXIT;
   ```
3. **导入表结构**：
   使用项目中的 `backend/iot-hotel-backend/database/init.sql` 进行初始化：
   ```bash
   mysql -u iot_user -p iot_hotel_system < /path/to/backend/iot-hotel-backend/database/init.sql
   ```

---

## 3. 后端服务部署 (iot-hotel-backend)

### 安装依赖与进程管理器
```bash
cd /var/www/iot-hotel-backend
npm install
sudo npm install -g pm2
```

### 配置环境变量
```bash
cp .env.example .env
nano .env
```
**关键配置项说明**：
- `DB_HOST`: 数据库主机地址
- `JWT_SECRET`: 使用 `openssl rand -base64 32` 生成强密钥
- `MQTT_HOST`: `mqtt://localhost`
- `ZHIPU_AI_API_KEY`: 智谱 AI 平台获取的密钥

### 编译并启动
```bash
npm run build
pm2 start dist/server.js --name "hotel-backend"
pm2 save
```

---

## 4. 前端服务部署 (iot-hotel-web)

### 构建静态资源
```bash
cd /var/www/iot-hotel-web
npm install
# 确保 .env.production 中的 VITE_API_URL 指向后端接口地址
npm run build
```

### Nginx 反向代理配置
安装 Nginx：
```bash
sudo apt install -y nginx
```
创建配置文件 `/etc/nginx/sites-available/iot-hotel`：
```nginx
server {
    listen 80;
    server_name your_domain_or_ip;

    # 前端静态页面
    location / {
        root /var/www/iot-hotel-web/dist;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # 后端 API 转发
    location /api/v1 {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
    }

    # WebSocket 实时通信转发
    location /socket.io {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }
}
```
激活配置并重启：
```bash
sudo ln -s /etc/nginx/sites-available/iot-hotel /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## 5. 安全与维护

- **防火墙配置**：
  ```bash
  sudo ufw allow 80/tcp
  sudo ufw allow 3000/tcp
  sudo ufw allow 1883/tcp
  ```
- **服务监控**：
  - 后端：`pm2 status` / `pm2 logs hotel-backend`
  - Nginx：`tail -f /var/log/nginx/error.log`
- **文件权限**：
  确保上传目录可写：`chmod -R 755 /var/www/iot-hotel-backend/uploads`

---

## 6. Docker 快捷部署 (推荐)

如果您希望快速搭建环境并避免手动配置依赖，可以使用 Docker 进行一键部署。

### 前置要求
- 已安装 **Docker** 和 **Docker Compose**。

### 部署步骤

1. **进入 Docker 目录**：
   ```bash
   cd /path/to/IoT_Smart_Hotel_System/docker
   ```

2. **准备初始化脚本**：
   将 `backend/iot-hotel-backend/database/init.sql` 复制到 `docker/mysql/init/` 目录下，MySQL 容器启动时会自动执行该目录下的 `.sql` 文件。

3. **配置环境变量**：
   编辑 `docker-compose.yml` 中的 `environment` 部分，重点检查：
   - `MYSQL_ROOT_PASSWORD`
   - `JWT_SECRET`
   - `ZHIPU_AI_API_KEY`

4. **一键启动**：
   ```bash
   docker-compose up -d
   ```

5. **查看运行状态**：
   ```bash
   docker-compose ps
   ```

### 容器说明
- **MySQL**: 挂载卷 `mysql-data` 持久化存储数据。
- **MQTT (Mosquitto)**: 挂载卷 `mqtt-data` 和 `mqtt-log`。
- **Backend**: 自动构建后端镜像并连接至同一网络。

> **注意**：前端服务通常仍建议通过 Nginx 部署在宿主机或单独的容器中，以获得最佳性能。

