# Nginx 配置修复指南

> **问题**: Nginx 配置文件引用的路径不正确  
> **解决方案**: 修复配置文件路径

---

## 🔍 问题分析

### 错误信息

```
ln: failed to create symbolic link '/etc/nginx/sites-enabled/iot-hotel': File exists
nginx: [emerg] open() "/etc/nginx/sites-enabled/iot-hotel-frontend" failed (2: No such file or directory)
```

### 问题原因

1. **符号链接已存在**：`/etc/nginx/sites-enabled/iot-hotel` 已经存在
2. **配置文件路径不匹配**：Nginx 主配置文件中引用的是 `iot-hotel-frontend`，但实际配置文件是 `iot-hotel`

---

## 🚀 解决方案

### 方案一：删除现有配置并重新创建（推荐）

```bash
# 1. 删除现有的符号链接
sudo rm /etc/nginx/sites-enabled/iot-hotel

# 2. 删除现有的配置文件（如果不需要）
sudo rm /etc/nginx/sites-available/iot-hotel

# 3. 创建新的配置文件
sudo vim /etc/nginx/sites-available/iot-hotel
```

**粘贴以下配置**：

```nginx
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

    # 访问日志
    access_log /var/log/nginx/iot-hotel-access.log;
    error_log /var/log/nginx/iot-hotel-error.log;
}
```

```bash
# 4. 创建符号链接
sudo ln -s /etc/nginx/sites-available/iot-hotel /etc/nginx/sites-enabled/

# 5. 测试配置
sudo nginx -t

# 6. 重启 Nginx
sudo systemctl restart nginx

# 7. 验证配置
curl http://localhost
curl http://localhost/api/v1/health
```

---

### 方案二：直接修改现有配置文件

如果现有配置文件内容是你想要的，直接修改它：

```bash
# 查看现有配置
cat /etc/nginx/sites-available/iot-hotel

# 编辑配置
sudo vim /etc/nginx/sites-available/iot-hotel

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

---

### 方案三：检查 Nginx 主配置文件

如果问题仍然存在，检查 Nginx 主配置文件：

```bash
# 查看 Nginx 主配置文件
cat /etc/nginx/nginx.conf

# 查找引用的配置文件
grep -r "sites-enabled" /etc/nginx/

# 查看当前启用的配置
ls -la /etc/nginx/sites-enabled/
```

**确保主配置文件中引用的是正确的配置文件**：

```nginx
http {
    # ...
    include /etc/nginx/sites-enabled/*;
    # ...
}
```

---

## 🔧 修复步骤

### 1. 检查当前配置状态

```bash
# 查看当前启用的配置
ls -la /etc/nginx/sites-enabled/

# 查看配置文件
cat /etc/nginx/sites-available/iot-hotel

# 查看主配置文件
grep -A 5 "sites-enabled" /etc/nginx/nginx.conf
```

### 2. 清理旧配置

```bash
# 删除所有旧的符号链接
sudo rm /etc/nginx/sites-enabled/*

# 删除所有旧的配置文件（如果不需要）
sudo rm /etc/nginx/sites-available/iot-hotel*
```

### 3. 创建新配置

```bash
# 创建新配置
sudo vim /etc/nginx/sites-available/iot-hotel
```

**粘贴配置内容**：

```nginx
server {
    listen 80;
    server_name 8.134.166.69;

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
    }

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

    access_log /var/log/nginx/iot-hotel-access.log;
    error_log /var/log/nginx/iot-hotel-error.log;
}
```

```bash
# 创建符号链接
sudo ln -s /etc/nginx/sites-available/iot-hotel /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

---

## 📋 验证清单

- [ ] 旧配置已清理
- [ ] 新配置已创建
- [ ] 符号链接已创建
- [ ] Nginx 配置测试通过
- [ ] Nginx 已重启
- [ ] 访问 `http://localhost` 显示前端页面
- [ ] 访问 `http://localhost/api/v1/health` 显示后端 API

---

## 🔄 常用命令

```bash
# 查看当前启用的配置
ls -la /etc/nginx/sites-enabled/

# 查看配置文件
cat /etc/nginx/sites-available/iot-hotel

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx

# 查看 Nginx 状态
sudo systemctl status nginx

# 查看错误日志
sudo tail -f /var/log/nginx/iot-hotel-error.log
```

---

## ⚠️ 注意事项

1. **确保配置文件路径一致**
   - 配置文件：`/etc/nginx/sites-available/iot-hotel`
   - 符号链接：`/etc/nginx/sites-enabled/iot-hotel`

2. **确保前端 dist 目录存在**
   ```bash
   ls -la /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
   ```

3. **确保后端服务已启动**
   ```bash
   pm2 status
   curl http://127.0.0.1:9000/api/v1/health
   ```

---

## 📚 参考资料

- [Nginx 官方文档](https://nginx.org/en/docs/)
- [Ubuntu Nginx 配置](https://ubuntu.com/server/docs/web-servers/nginx)

---

**最后更新**: 2026-04-07
