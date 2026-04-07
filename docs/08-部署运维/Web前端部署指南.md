# Web 前端部署指南

> **版本**: v1.0.0\
> **更新日期**: 2026-04-07\
> **前端技术栈**: Vue 3 + Vite + Ant Design Vue

***

## 📋 部署步骤

### 步骤 1：克隆项目代码

```bash
# 进入工作目录
cd ~

# 克隆项目
git clone https://github.com/choisaaaaa/IoT_Smart_Hotel_System.git
cd IoT_Smart_Hotel_System/frontend/iot-hotel-web
```

### 步骤 2：安装依赖

```bash
# 安装 Node.js 依赖
npm install

# 或使用淘宝镜像加速
npm install --registry=https://registry.npmmirror.com
```

### 步骤 3：构建项目

```bash
# 构建生产版本
npm run build

# 构建完成后，会在项目根目录生成 dist 目录
```

### 步骤 4：配置 Nginx

```bash
# 创建 Nginx 配置
sudo vim /etc/nginx/sites-available/iot-hotel-frontend
```

**配置内容**：

```nginx
# Web 前端服务器
server {
    listen 80;
    server_name 8.134.166.69;  # 替换为你的服务器IP

    # 前端静态文件路径
    root /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
    index index.html;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/x-javascript
        application/xml
        application/json;

    # 缓存配置
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf)$ {
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    # SPA 路由支持
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 错误页面
    error_page 404 /index.html;
    location = /404.html {
        internal;
        alias /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist/index.html;
    }

    # 访问日志
    access_log /var/log/nginx/iot-hotel-frontend-access.log;
    error_log /var/log/nginx/iot-hotel-frontend-error.log;
}
```

### 步骤 5：启用配置

```bash
# 创建软链接
sudo ln -s /etc/nginx/sites-available/iot-hotel-frontend /etc/nginx/sites-enabled/

# 删除默认配置（可选）
sudo rm /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

### 步骤 6：验证部署

```bash
# 访问前端
http://8.134.166.69

# 检查 Nginx 状态
sudo systemctl status nginx

# 查看访问日志
sudo tail -f /var/log/nginx/iot-hotel-frontend-access.log
```

***

## 🎯 访问地址

- **前端首页**: http://8.134.166.69
- **API 接口**: http://8.134.166.69/api
- **WebSocket**: ws://8.134.166.69/ws

***

## 📝 注意事项

1. **确保 dist 目录存在**：
   ```bash
   ls -la /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
   ```

2. **确保 Nginx 有读取权限**：
   ```bash
   sudo chown -R www-data:www-data /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
   sudo chmod -R 755 /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
   ```

3. **SPA 路由支持**：
   - 配置了 `try_files $uri $uri/ /index.html` 来支持 Vue Router 的 history 模式
   - 刷新页面不会出现 404 错误

4. **Gzip 压缩**：
   - 已启用 Gzip 压缩，减少传输大小
   - 可以进一步优化：调整 `gzip_types` 和 `gzip_min_length`

5. **缓存策略**：
   - 静态资源缓存 7 天
   - HTML 文件不缓存

***

## 🔧 常见问题

### 问题 1：403 Forbidden

**原因**：Nginx 没有权限访问文件

**解决方案**：
```bash
sudo chown -R www-data:www-data /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
sudo chmod -R 755 /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist
```

### 问题 2：502 Bad Gateway

**原因**：Nginx 配置错误

**解决方案**：
```bash
# 测试配置
sudo nginx -t

# 查看错误日志
sudo tail -f /var/log/nginx/iot-hotel-frontend-error.log
```

### 问题 3：刷新页面 404

**原因**：SPA 路由配置错误

**解决方案**：
确保配置中有：
```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

### 问题 4：静态资源 404

**原因**：root 路径错误

**解决方案**：
检查 `root` 路径是否正确：
```nginx
root /root/IoT_Smart_Hotel_System/frontend/iot-hotel-web/dist;
```

***

## 📊 性能优化建议

### 1. 启用 Brotli 压缩（比 Gzip 更好）

```bash
# 安装 Brotli 模块
sudo apt install -y libnginx-mod-brotli

# 在 Nginx 配置中添加
brotli on;
brotli_comp_level 6;
brotli_types text/plain text/css application/json application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript;
```

### 2. HTTP/2 支持

```nginx
# 启用 HTTP/2（需要 SSL）
listen 443 ssl http2;
```

### 3. 预加载关键资源

```nginx
# 在 server 块中添加
location / {
    add_header Link "</css/chunk-vendors.css>; rel=preload; as=style" always;
    add_header Link "</js/chunk-vendors.js>; rel=preload; as=script" always;
    add_header Link "</js/app.js>; rel=preload; as=script" always;
}
```

### 4. CDN 加速（可选）

将静态资源上传到 CDN，如：
- 阿里云 OSS + CDN
- 腾讯云 COS + CDN
- 七牛云

***

## 🔄 更新部署

每次更新前端代码后，执行：

```bash
# 进入项目目录
cd ~/IoT_Smart_Hotel_System/frontend/iot-hotel-web

# 拉取最新代码
git pull

# 安装新依赖（如果有）
npm install

# 重新构建
npm run build

# 重启 Nginx（可选）
sudo systemctl restart nginx
```

***

## 📋 部署检查清单

- [ ] 项目代码已克隆
- [ ] Node.js 已安装（v20.x LTS）
- [ ] 依赖已安装
- [ ] 项目已构建（dist 目录存在）
- [ ] Nginx 配置已创建
- [ ] Nginx 配置已启用
- [ ] Nginx 已重启
- [ ] 前端可以正常访问
- [ ] SPA 路由正常（刷新页面不 404）
- [ ] 静态资源正常加载
- [ ] Gzip 压缩生效

***

## 🎯 下一步

1. **配置 HTTPS**：使用 Let's Encrypt 免费证书
2. **域名解析**：配置 DNS 解析到服务器 IP
3. **CI/CD**：配置自动化部署
4. **监控告警**：配置前端性能监控

***

**最后更新**: 2026-04-07
