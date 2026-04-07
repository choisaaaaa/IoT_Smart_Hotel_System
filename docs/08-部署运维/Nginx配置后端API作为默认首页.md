# Nginx 配置 - 后端 API 作为默认首页

> **版本**: v1.0.0  
> **更新日期**: 2026-04-07  
> **配置目标**: `http://8.134.166.69` 默认显示后端 API

---

## 📋 配置说明

### 当前需求

- **默认首页**: `http://8.134.166.69` → 后端 API
- **API 接口**: `http://8.134.166.69/api` → 后端 API
- **前端页面**: `http://8.134.166.69/web` → 前端页面（可选）

---

## 🔧 Nginx 配置

### 配置文件位置

```bash
# 编辑 Nginx 配置
sudo vim /etc/nginx/sites-available/iot-hotel
```

### 配置内容

```nginx
# HTTP 服务器
server {
    listen 80;
    server_name 8.134.166.69;

    # ==========================================
    # 后端 API 服务
    # ==========================================

    # 根路径 - 默认显示后端 API
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # API 代理
    location /api {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket 代理
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
    # 前端页面服务（可选）
    # ==========================================

    # 前端页面（通过 /web 访问）
    location /web {
        alias /root/iot-hotel-system/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
        index index.html;
        try_files $uri $uri/ /web/index.html;
    }

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf)$ {
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    # 访问日志
    access_log /var/log/nginx/iot-hotel-access.log;
    error_log /var/log/nginx/iot-hotel-error.log;
}
```

---

## 🚀 配置步骤

### 1. 编辑 Nginx 配置

```bash
# 编辑配置文件
sudo vim /etc/nginx/sites-available/iot-hotel
```

**粘贴上述配置内容**

### 2. 测试配置

```bash
# 测试 Nginx 配置
sudo nginx -t
```

**预期输出**：
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 3. 重启 Nginx

```bash
# 重启 Nginx
sudo systemctl restart nginx

# 或重新加载配置
sudo systemctl reload nginx
```

### 4. 验证配置

```bash
# 测试根路径（应该显示后端 API）
curl http://localhost

# 测试 API 路径
curl http://localhost/api/v1/health

# 测试前端页面（通过 /web）
curl -I http://localhost/web
```

**预期输出**：

**根路径**：
```json
{
  "code": 200,
  "message": "智慧酒店物联网控制系统API",
  "timestamp": 1775574548935,
  "version": "2.0.0",
  "endpoints": {
    "health": "/health",
    "docs": "/api/v1/docs"
  }
}
```

**API 路径**：
```json
{
  "code": 200,
  "message": "服务正常",
  "timestamp": 1775574548935,
  "version": "2.0.0"
}
```

---

## 📋 访问地址说明

| 地址 | 说明 |
|------|------|
| `http://8.134.166.69` | **后端 API**（默认首页） |
| `http://8.134.166.69/api` | 后端 API |
| `http://8.134.166.69/ws` | WebSocket |
| `http://8.134.166.69/web` | 前端页面（可选） |

---

## 🔄 如果要恢复前端作为默认首页

如果之后想把前端作为默认首页，修改配置如下：

```nginx
# 根路径 - 默认显示前端页面
location / {
    root /root/iot-hotel-system/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
    index index.html;
    try_files $uri $uri/ /index.html;
}

# API 代理
location /api {
    proxy_pass http://127.0.0.1:9000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

---

## ⚙️ 其他配置选项

### 1. 同时支持前端和后端

```nginx
# 后端 API
location /api {
    proxy_pass http://127.0.0.1:9000;
    # ... 其他配置
}

# 前端页面
location / {
    root /root/iot-hotel-system/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
    index index.html;
    try_files $uri $uri/ /index.html;
}
```

### 2. 使用子域名区分

```nginx
# 后端 API
server {
    listen 80;
    server_name api.8.134.166.69.nip.io;
    
    location / {
        proxy_pass http://127.0.0.1:9000;
        # ... 其他配置
    }
}

# 前端页面
server {
    listen 80;
    server_name web.8.134.166.69.nip.io;
    
    location / {
        root /root/iot-hotel-system/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}
```

---

## 📋 配置检查清单

- [ ] Nginx 配置已编辑
- [ ] Nginx 配置测试通过
- [ ] Nginx 已重启
- [ ] 根路径显示后端 API
- [ ] API 路径正常工作
- [ ] WebSocket 正常工作
- [ ] 前端页面可访问（如果配置）

---

## 🎯 快速验证命令

```bash
# 测试根路径（后端 API）
curl http://8.134.166.69

# 测试 API
curl http://8.134.166.69/api/v1/health

# 测试前端页面（如果配置）
curl -I http://8.134.166.69/web

# 查看 Nginx 状态
sudo systemctl status nginx

# 查看访问日志
sudo tail -f /var/log/nginx/iot-hotel-access.log
```

---

**最后更新**: 2026-04-07
