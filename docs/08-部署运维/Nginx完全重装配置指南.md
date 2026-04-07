# Nginx 完全重装配置指南

## 1. 卸载旧版本 Nginx

```bash
# 停止 Nginx 服务
sudo systemctl stop nginx

# 卸载 Nginx
sudo apt-get purge nginx nginx-common nginx-core -y

# 删除配置文件
sudo rm -rf /etc/nginx
sudo rm -rf /etc/nginx/sites-available
sudo rm -rf /etc/nginx/sites-enabled
sudo rm -rf /var/log/nginx
sudo rm -rf /var/www

# 清理残留
sudo apt-get autoremove -y
sudo apt-get autoclean -y
```

## 2. 安装 Nginx

```bash
# 更新包列表
sudo apt-get update

# 安装 Nginx
sudo apt-get install nginx -y

# 检查安装版本
nginx -v

# 启动 Nginx
sudo systemctl start nginx

# 设置开机自启
sudo systemctl enable nginx

# 检查状态
sudo systemctl status nginx
```

## 3. 创建站点目录

```bash
# 前端目录（项目已存在）
# /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist

# 后端目录（项目已存在）
# /root/IoT_Smart_Hotel_System/backend/iot-hotel-backend

# 检查目录是否存在
ls -la /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
ls -la /root/IoT_Smart_Hotel_System/backend/iot-hotel-backend
```

## 4. 配置前后端站点

### 方案一：单服务器块配置（推荐）

```bash
# 创建站点配置文件
sudo vim /etc/nginx/sites-available/iot-hotel
```

**配置内容：**

```nginx
# 前端静态文件 + 后端 API 服务器
server {
    listen 80;
    server_name 8.134.166.69;

    # 前端静态文件（默认首页）
    location / {
        root /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # 后端 API 代理
    location /api {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 后端服务代理（用于其他后端接口）
    location /backend {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 健康检查
    location /health {
        proxy_pass http://127.0.0.1:9000/api/v1/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }

    # 后端日志
    access_log /var/log/nginx/iot-hotel-access.log;
    error_log /var/log/nginx/iot-hotel-error.log;
}
```

### 方案二：多服务器块配置（分离部署）

```bash
# 创建前端站点配置
sudo vim /etc/nginx/sites-available/iot-hotel-frontend
```

**前端配置：**

```nginx
server {
    listen 80;
    server_name 8.134.166.69;

    root /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    access_log /var/log/nginx/iot-hotel-frontend-access.log;
    error_log /var/log/nginx/iot-hotel-frontend-error.log;
}
```

```bash
# 创建后端站点配置（可选，用于独立访问）
sudo vim /etc/nginx/sites-available/iot-hotel-backend
```

**后端配置：**

```nginx
server {
    listen 8080;
    server_name 8.134.166.69;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    access_log /var/log/nginx/iot-hotel-backend-access.log;
    error_log /var/log/nginx/iot-hotel-backend-error.log;
}
```

**启用配置：**

```bash
# 前端
sudo ln -sf /etc/nginx/sites-available/iot-hotel-frontend /etc/nginx/sites-enabled/
# 后端（可选）
sudo ln -sf /etc/nginx/sites-available/iot-hotel-backend /etc/nginx/sites-enabled/

sudo rm -f /etc/nginx/sites-enabled/default
```

## 5. 启用配置

```bash
# 创建符号链接
sudo ln -s /etc/nginx/sites-available/iot-hotel /etc/nginx/sites-enabled/

# 删除默认配置（避免冲突）
sudo rm -f /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx

# 设置开机自启
sudo systemctl enable nginx

# 开放 HTTPS 端口
sudo ufw allow 443/tcp
```

## 6. 验证配置

```bash
# 检查 Nginx 状态
sudo systemctl status nginx

# 测试访问 - 前端
curl http://localhost

# 测试访问 - 后端 API
curl http://localhost/api/v1/health

# 测试访问 - 后端服务
curl http://localhost/backend/api/v1/health

# HTTPS 测试（如果已配置）
curl -k https://localhost
curl -k https://localhost/api/v1/health

# 查看日志
tail -f /var/log/nginx/iot-hotel-access.log
tail -f /var/log/nginx/iot-hotel-error.log

# 检查端口
sudo netstat -tuln | grep -E ':(80|443)\s'
```

## 7. 防火墙配置

```bash
# 开放 HTTP 端口
sudo ufw allow 80/tcp

# 开放 HTTPS 端口
sudo ufw allow 443/tcp

# 检查防火墙状态
sudo ufw status

# 如果需要重置防火墙
# sudo ufw reset
# sudo ufw allow 22/tcp
# sudo ufw allow 80/tcp
# sudo ufw allow 443/tcp
# sudo ufw allow 3306/tcp
```

## 8. 常见问题排查

### 8.1 配置文件错误

```bash
# 检查配置文件语法
sudo nginx -t

# 查看详细错误
sudo journalctl -xeu nginx.service
```

### 8.2 500 错误排查

```bash
# 1. 检查 Nginx 错误日志
sudo tail -n 100 /var/log/nginx/iot-hotel-error.log

# 2. 检查前端目录是否存在
ls -la /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist

# 3. 检查 index.html 是否存在
ls -la /root/IoT_Hotel_System/frontend/iot-hotel-web/dist/index.html

# 4. 检查目录权限
sudo ls -la /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/

# 5. 检查 Nginx 用户
sudo cat /etc/nginx/nginx.conf | grep user

# 6. 修复权限（如果需要）
sudo chown -R www-data:www-data /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
sudo chmod -R 755 /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist

# 7. 重启 Nginx
sudo systemctl restart nginx
```

### 8.3 权限问题

```bash
# 检查目录权限
ls -la /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist

# 修复权限
sudo chown -R www-data:www-data /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
sudo chmod -R 755 /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
```

### 8.3 端口占用

```bash
# 检查 80 端口占用
sudo netstat -tuln | grep :80

# 或使用 lsof
sudo lsof -i :80

# 查找并杀死占用进程
sudo fuser -k 80/tcp
```

### 8.4 重启 Nginx

```bash
# 平滑重启
sudo nginx -s reload

# 或使用 systemctl
sudo systemctl restart nginx
```

## 9. 完整配置验证脚本

```bash
#!/bin/bash

echo "=== Nginx 配置验证 ==="

# 1. 检查 Nginx 状态
echo "1. 检查 Nginx 服务状态..."
sudo systemctl status nginx --no-pager

# 2. 测试配置文件
echo "2. 测试配置文件..."
sudo nginx -t

# 3. 测试访问
echo "3. 测试访问..."
curl -s http://localhost | head -20
curl -s http://localhost/api/v1/health

# 4. 查看日志
echo "4. 查看最近日志..."
tail -n 50 /var/log/nginx/iot-hotel-access.log
tail -n 50 /var/log/nginx/iot-hotel-error.log

# 5. 检查端口
echo "5. 检查 80 端口..."
sudo netstat -tuln | grep :80

echo "=== 验证完成 ==="
```

## 10. 备份与恢复

### 10.1 备份配置

```bash
# 备份当前配置
sudo tar -czvf nginx-backup-$(date +%Y%m%d-%H%M%S).tar.gz /etc/nginx

# 备份站点目录
sudo tar -czvf frontend-backup-$(date +%Y%m%d-%H%M%S).tar.gz /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
```

### 10.2 恢复配置

```bash
# 恢复配置（替换备份文件名）
sudo tar -xzvf nginx-backup-20240101-120000.tar.gz -C /

# 重启 Nginx
sudo systemctl restart nginx
```

## 11. 生产环境建议

### 11.1 性能优化

```nginx
# 在 http 块中添加
http {
    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml application/javascript application/json;

    # 连接优化
    keepalive_timeout 65;
    client_max_body_size 10M;

    # 缓存静态文件
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### 11.2 安全配置

```nginx
# 隐藏版本号
server_tokens off;

# 防止点击劫持
add_header X-Frame-Options "SAMEORIGIN" always;

# 防止 XSS 攻击
add_header X-XSS-Protection "1; mode=block" always;

# 防止 MIME 类型嗅探
add_header X-Content-Type-Options "nosniff" always;

# CSP 策略（根据需要调整）
add_header Content-Security-Policy "default-src 'self';" always;
```

## 11.3 HTTPS 配置

### 11.3.1 获取 SSL 证书

**使用 Let's Encrypt（免费）：**

```bash
# 安装 Certbot
sudo apt-get install certbot python3-certbot-nginx -y

# 获取证书
sudo certbot --nginx -d 8.134.166.69

# 或者使用域名（如果有）
sudo certbot --nginx -d your-domain.com
```

**手动配置 SSL（适用于 IP 地址）：**

```bash
# 创建证书目录
sudo mkdir -p /etc/nginx/ssl

# 生成自签名证书（测试环境）
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt

# 填写证书信息（可以随意填写）
# Country Name (2 letter code) [AU]: CN
# State or Province Name (full name) [Some-State]: Beijing
# Locality Name (eg, city) []: Beijing
# Organization Name (eg, company) [Internet Widgits Pty Ltd]: IoT
# Organizational Unit Name (eg, section) []: Tech
# Common Name (e.g. server FQDN or YOUR name) []: 8.134.166.69
# Email Address []: admin@example.com
```

### 11.3.2 HTTPS 配置示例

```nginx
# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name 8.134.166.69;
    
    # 所有请求重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

# HTTPS 服务器
server {
    listen 443 ssl;
    server_name 8.134.166.69;

    # SSL 证书配置
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    # SSL 设置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 前端静态文件（默认首页）
    location / {
        root /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # 后端 API 代理
    location /api {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # 后端服务代理
    location /backend {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 健康检查
    location /health {
        proxy_pass http://127.0.0.1:9000/api/v1/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }

    access_log /var/log/nginx/iot-hotel-ssl-access.log;
    error_log /var/log/nginx/iot-hotel-ssl-error.log;
}

### 11.3.3 自动续期证书

```bash
# Let's Encrypt 证书自动续期（已自动配置）
# 测试续期
sudo certbot renew --dry-run

# 手动续期
sudo certbot renew
```

## 11.4 HTTPS 完整配置示例

### 11.4.1 单服务器块（HTTP + HTTPS）

```nginx
# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name 8.134.166.69;
    
    return 301 https://$server_name$request_uri;
}

# HTTPS 服务器
server {
    listen 443 ssl;
    server_name 8.134.166.69;

    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        root /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /backend {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://127.0.0.1:9000/api/v1/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }

    access_log /var/log/nginx/iot-hotel-ssl-access.log;
    error_log /var/log/nginx/iot-hotel-ssl-error.log;
}
```

### 11.4.2 启用 HTTPS 配置

```bash
# 1. 生成 SSL 证书
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt

# 2. 创建配置文件
sudo tee /etc/nginx/sites-available/iot-hotel-ssl > /dev/null <<EOF
# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name 8.134.166.69;
    
    return 301 https://\$server_name\$request_uri;
}

# HTTPS 服务器
server {
    listen 443 ssl;
    server_name 8.134.166.69;

    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        root /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /backend {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /health {
        proxy_pass http://127.0.0.1:9000/api/v1/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }

    access_log /var/log/nginx/iot-hotel-ssl-access.log;
    error_log /var/log/nginx/iot-hotel-ssl-error.log;
}
EOF

# 3. 启用配置
sudo ln -sf /etc/nginx/sites-available/iot-hotel-ssl /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 4. 测试并重启
sudo nginx -t
sudo systemctl restart nginx

# 5. 开放防火墙
sudo ufw allow 443/tcp
```

## 12. 卸载清理脚本

```bash
#!/bin/bash

echo "=== 卸载 Nginx ==="

# 停止服务
sudo systemctl stop nginx
sudo systemctl disable nginx

# 卸载包
sudo apt-get purge nginx nginx-common nginx-core -y

# 删除配置
sudo rm -rf /etc/nginx
sudo rm -rf /var/log/nginx

# 清理依赖
sudo apt-get autoremove -y
sudo apt-get autoclean -y

echo "=== 卸载完成 ==="
```

## 13. 一键安装脚本

```bash
#!/bin/bash

echo "=== 一键安装 Nginx ==="

# 更新包列表
sudo apt-get update

# 安装 Nginx
sudo apt-get install nginx -y

# 创建站点目录
sudo mkdir -p /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist

# 创建配置文件
sudo tee /etc/nginx/sites-available/iot-hotel > /dev/null <<EOF
server {
    listen 80;
    server_name 8.134.166.69;

    location / {
        root /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 启用配置
sudo ln -sf /etc/nginx/sites-available/iot-hotel /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 测试并重启
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "=== 安装完成 ==="
```

## 14. 验证清单

- [ ] Nginx 已安装并运行
- [ ] 配置文件语法正确
- [ ] 符号链接已创建
- [ ] 默认配置已删除
- [ ] 前端静态文件可访问
- [ ] 后端 API 代理正常工作
- [ ] 后端服务可访问
- [ ] 防火墙已开放 80 端口
- [ ] 服务已设置开机自启
- [ ] 日志文件正常生成
- [ ] 健康检查接口正常

## 15. 快速故障排查

| 问题 | 解决方案 |
|------|----------|
| `File not found` | 检查站点目录是否存在，权限是否正确 |
| `Address already in use` | 检查 80 端口是否被占用 |
| `Permission denied` | 检查 Nginx 用户权限 |
| `404 Not Found` | 检查站点配置和文件路径 |
| `502 Bad Gateway` | 检查后端服务是否运行 |
| `504 Gateway Timeout` | 检查后端服务响应时间 |
| `前端无法访问` | 检查 dist 目录是否存在，index.html 是否生成 |
| `API 代理失败` | 检查后端服务是否监听 9000 端口 |
| `后端服务无法访问` | 检查后端服务配置和端口 |
| `500 Internal Server Error` | 检查 Nginx 错误日志、目录权限、index.html 是否存在 |
