# Nginx 配置 - 前端作为默认首页

> **问题**: 访问 `http://8.134.166.69` 显示后端 API，希望显示前端页面  
> **解决方案**: 修改 Nginx 配置，将前端作为默认首页

---

## 📋 问题分析

### 当前配置问题

你当前的 Nginx 配置可能将后端 API 作为默认首页，导致访问 `http://8.134.166.69` 时返回后端 API 信息。

**当前输出**：
```json
{
  "code": 200,
  "message": "智慧酒店物联网控制系统API",
  "timestamp": 1775574683077,
  "version": "2.0.0",
  "endpoints": {
    "health": "/health",
    "docs": "/api/v1/docs"
  }
}
```

### 正确配置目标

**期望输出**：
```
http://8.134.166.69 → 显示前端 Vue3 页面
http://8.134.166.69/api → 代理到后端 API
http://8.134.166.69/ws → 代理到 WebSocket
```

---

## 🔧 解决方案

### 方案一：前端作为默认首页（推荐）

将前端静态文件作为根路径 `/`，后端 API 作为 `/api` 路径。

```bash
# 创建 Nginx 配置
sudo vim /etc/nginx/sites-available/iot-hotel
```

**配置内容**：

```nginx
# Web 前端服务器（前端作为默认首页）
server {
    listen 80;
    server_name 8.134.166.69;

    # ==========================================
    # 前端静态文件（默认首页）
    # ==========================================
    location / {
        root /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
        index index.html;
        try_files $uri $uri/ /index.html;
        
        # 前端缓存配置
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf)$ {
            expires 7d;
            add_header Cache-Control "public, immutable";
        }
    }

    # ==========================================
    # 后端 API 代理
    # ==========================================
    location /api {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # ==========================================
    # WebSocket 代理
    # ==========================================
    location /ws {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

    # ==========================================
    # 健康检查（可选）
    # ==========================================
    location /health {
        proxy_pass http://127.0.0.1:9000/health;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }

    # ==========================================
    # 错误页面
    # ==========================================
    error_page 404 /index.html;
    location = /404.html {
        internal;
        alias /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist/index.html;
    }

    # ==========================================
    # 日志配置
    # ==========================================
    access_log /var/log/nginx/iot-hotel-frontend-access.log;
    error_log /var/log/nginx/iot-hotel-frontend-error.log;
}
```

### 方案二：使用反向代理（如果前端也在后端服务中）

如果你的前端是通过后端服务提供（如 Spring Boot），使用以下配置：

```nginx
server {
    listen 80;
    server_name 8.134.166.69;

    # 根路径 - 前端页面
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # API 路径 - 后端 API
    location /api {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket
    location /ws {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
}
```

---

## 🚀 部署步骤

### 步骤 1：创建 Nginx 配置

```bash
# 创建配置文件
sudo vim /etc/nginx/sites-available/iot-hotel
```

**粘贴方案一的配置内容**

### 步骤 2：启用配置

```bash
# 创建软链接
sudo ln -s /etc/nginx/sites-available/iot-hotel /etc/nginx/sites-enabled/

# 删除默认配置（如果有）
sudo rm /etc/nginx/sites-enabled/default 2>/dev/null || true

# 测试配置
sudo nginx -t
```

**预期输出**：
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 步骤 3：重启 Nginx

```bash
# 重启 Nginx
sudo systemctl restart nginx

# 或重新加载配置
sudo systemctl reload nginx
```

### 步骤 4：验证配置

```bash
# 访问前端首页
curl http://localhost

# 访问 API
curl http://localhost/api/v1/health

# 访问健康检查
curl http://localhost/health
```

**预期输出**：

1. **前端首页**（HTML 内容）：
```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <title>智慧酒店物联网控制系统</title>
</head>
<body>
  <div id="app"></div>
</body>
</html>
```

2. **API 接口**（JSON）：
```json
{
  "code": 200,
  "message": "服务正常",
  "timestamp": 1775574683077,
  "version": "2.0.0"
}
```

---

## 🔍 故障排查

### 问题 1：仍然显示后端 API

**检查配置**：

```bash
# 查看当前 Nginx 配置
cat /etc/nginx/sites-enabled/iot-hotel

# 检查配置是否正确
sudo nginx -t

# 查看 Nginx 错误日志
sudo tail -f /var/log/nginx/iot-hotel-frontend-error.log
```

**解决方案**：

确保配置中：
1. `location /` 指向前端静态文件
2. `location /api` 代理到后端 API
3. 没有其他配置覆盖根路径

### 问题 2：前端页面 404

**检查文件路径**：

```bash
# 检查前端 dist 目录是否存在
ls -la /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist

# 检查文件权限
sudo chown -R www-data:www-data /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
sudo chmod -R 755 /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
```

### 问题 3：API 无法访问

**检查后端服务**：

```bash
# 检查后端服务状态
pm2 status

# 检查后端日志
pm2 logs iot-hotel-backend

# 测试本地 API
curl http://127.0.0.1:9000/api/v1/health
```

### 问题 4：SPA 路由刷新 404

**检查配置**：

确保配置中有：
```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

---

## 📋 验证清单

- [ ] Nginx 配置已更新
- [ ] Nginx 配置已测试通过
- [ ] Nginx 已重启
- [ ] 访问 `http://8.134.166.69` 显示前端页面
- [ ] 访问 `http://8.134.166.69/api/v1/health` 显示后端 API
- [ ] 前端 SPA 路由正常（刷新页面不 404）
- [ ] 静态资源正常加载

---

## 🔄 常用命令

```bash
# 查看 Nginx 配置
cat /etc/nginx/sites-enabled/iot-hotel

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx

# 重新加载配置
sudo systemctl reload nginx

# 查看 Nginx 状态
sudo systemctl status nginx

# 查看访问日志
sudo tail -f /var/log/nginx/iot-hotel-frontend-access.log

# 查看错误日志
sudo tail -f /var/log/nginx/iot-hotel-frontend-error.log
```

---

## 📚 参考资料

- [Nginx 官方文档](https://nginx.org/en/docs/)
- [Vue Router History 模式](https://router.vuejs.org/zh/guide/essentials/history-mode.html)

---

**最后更新**: 2026-04-07
