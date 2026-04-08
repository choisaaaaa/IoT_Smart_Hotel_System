# 智慧酒店物联网控制系统 - 后端服务

## 📚 项目说明

智慧酒店物联网控制系统后端服务，提供RESTful API、WebSocket、MQTT等服务。

## 🚀 快速开始

### 1. 环境要求

- Node.js 20.x 或更高版本
- MySQL 8.0 或更高版本
- Redis 7.x 或更高版本
- MQTT Broker (如 Mosquitto)

### 2. 安装依赖

```bash
cd backend/iot-hotel-backend
npm install
```

### 3. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env` 文件，填写数据库连接信息：

```env
# 数据库配置
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=iot_hotel_system
```

### 4. 初始化数据库

执行 `docker/mysql/init/schema.sql` 中的SQL语句初始化数据库。

### 5. 启动服务器

```bash
npm run dev
```

服务器将在 `http://localhost:3000` 启动。

### 6. 测试API

```bash
curl http://localhost:3000/api/v1/health
```

## 📊 API接口

接口基路径：`/api/v1`  
除 `health` 和部分登录接口外，其余接口默认需要 `Authorization: Bearer <token>`。

### 1. 酒店管理接口

- `GET /api/v1/hotel` - 获取当前登录酒店信息
- `PUT /api/v1/hotel` - 更新当前登录酒店信息
- `GET /api/v1/hotels` - 获取酒店信息
- `PUT /api/v1/hotels` - 更新酒店信息
- `GET /api/v1/hotels/search` - 酒店搜索
- `GET /api/v1/hotels/:id` - 酒店详情
- `GET /api/v1/hotels/:id/availability` - 指定日期房态余量

### 2. 房间管理接口

- `GET /api/v1/rooms` - 获取房间列表
- `GET /api/v1/rooms/:id` - 获取房间详情
- `POST /api/v1/rooms` - 创建房间
- `PUT /api/v1/rooms/:id` - 更新房间
- `DELETE /api/v1/rooms/:id` - 删除房间
- `PUT /api/v1/rooms/:id/status` - 更新房态
- `GET /api/v1/room-types` - 房型列表
- `POST /api/v1/room-types` - 新建房型
- `PUT /api/v1/room-types/:id` - 更新房型

### 3. 预订管理接口

- `GET /api/v1/bookings` - 获取预订列表
- `GET /api/v1/bookings/:id` - 获取预订详情
- `POST /api/v1/bookings` - 创建预订
- `PUT /api/v1/bookings/:id/confirm` - 确认预订
- `PUT /api/v1/bookings/:id/checkin` - 办理入住
- `PUT /api/v1/bookings/:id/checkout` - 办理退房
- `PUT /api/v1/bookings/:id/cancel` - 取消预订

### 4. 支付管理接口

- `GET /api/v1/payments` - 获取支付列表
- `GET /api/v1/payments/:id` - 获取支付详情
- `POST /api/v1/payments` - 创建支付订单
- `PUT /api/v1/payments/:id/pay` - 支付

### 5. 会员管理接口

- `GET /api/v1/members` - 获取会员列表
- `GET /api/v1/members/:id` - 获取会员详情
- `POST /api/v1/members` - 注册会员
- `PUT /api/v1/members/:id` - 更新会员信息
- `POST /api/v1/members/login` - 会员登录

### 6. 优惠券管理接口

- `GET /api/v1/coupons` - 获取优惠券列表
- `GET /api/v1/coupons/:id` - 获取优惠券详情
- `POST /api/v1/coupons` - 创建优惠券
- `PUT /api/v1/coupons/:id` - 更新优惠券
- `DELETE /api/v1/coupons/:id` - 删除优惠券
- `POST /api/v1/coupons/:id/receive` - 领取优惠券

### 7. 送物订单接口

- `GET /api/v1/delivery` - 获取送物订单列表
- `GET /api/v1/delivery/:id` - 获取送物订单详情
- `POST /api/v1/delivery` - 创建送物订单
- `PUT /api/v1/delivery/:id/complete` - 完成送物订单

### 8. 报修工单接口

- `GET /api/v1/maintenance` - 获取报修工单列表
- `GET /api/v1/maintenance/:id` - 获取报修工单详情
- `POST /api/v1/maintenance` - 创建报修工单
- `PUT /api/v1/maintenance/:id/assign` - 分配维修人员
- `PUT /api/v1/maintenance/:id/complete` - 完成报修工单

### 9. 服务评价接口

- `GET /api/v1/reviews` - 获取评价列表
- `GET /api/v1/reviews/:id` - 获取评价详情
- `POST /api/v1/reviews` - 创建评价

### 10. 健康检查

- `GET /api/v1/health` - 服务健康状态

## ✅ 本次对齐与测试结论（2026-04）

- 已完成数据库结构对齐脚本执行：`align_api_schema_v260.sql`
- 已验证核心兼容字段存在：`bookings.hotel_id`、`rooms.hotel_id`、`rooms.room_id`、`users.hotel_id`、`devices.hotel_id`、`hotels.hotel_code`
- `npm run build` 与 `npm run type-check` 通过
- 项目当前 `npm run lint` 存在历史问题（大量 warning + 部分 error），不属于本次数据库对齐新增问题

## 🐳 Docker部署

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
docker-compose logs -f
```

### 5. 停止服务

```bash
docker-compose down
```

## 📁 项目结构

```
backend/iot-hotel-backend/
├── src/
│   ├── config/          # 配置文件
│   ├── controllers/     # 控制器层
│   ├── services/        # 服务层
│   ├── models/          # 数据模型
│   ├── routes/          # 路由
│   ├── middleware/      # 中间件
│   ├── utils/           # 工具函数
│   ├── types/           # 类型定义
│   ├── app.ts           # 应用入口
│   └── server.ts        # 服务器入口
├── docs/                # 文档
├── .env                 # 环境变量
├── tsconfig.json        # TypeScript配置
├── package.json         # 项目配置
└── README.md            # 项目说明
```

## 🔐 认证授权

### JWT认证

在请求头中添加Authorization字段：

```
Authorization: Bearer <your_jwt_token>
```

### 设备认证

在请求头中添加Device-Id和Device-Key字段：

```
Device-Id: <device_id>
Device-Key: <device_key>
```

## 📝 开发规范

### 1. 代码风格

- 使用TypeScript进行开发
- 遵循ESLint规则
- 使用Prettier格式化代码

### 2. 命名规范

- 变量和函数使用驼峰命名法 (camelCase)
- 类和接口使用帕斯卡命名法 (PascalCase)
- 常量使用大写下划线命名法 (SCREAMING_SNAKE_CASE)

### 3. 注释规范

- 所有公共函数和类需要添加注释
- 复杂逻辑需要添加注释

## 🐛 常见问题

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
```

### 3. 依赖安装失败

```bash
# 清除缓存
npm cache clean --force

# 重新安装
npm install
```

## 📚 相关文档

- [项目结构说明](./docs/项目结构说明.md)
- [数据库配置说明](./docs/数据库配置说明.md)
- [启动指南](./docs/启动指南.md)
- [完整部署指南](./docs/完整部署指南.md)
- [Docker配置说明](./docs/Docker配置说明.md)

## 🔮 未来计划

1. **前端开发**: 实现Vue.js前端界面
2. **设备管理**: 实现设备配网和控制
3. **数据分析**: 实现数据统计和分析
4. **AI服务**: 集成AI客服和推荐系统
5. **移动端**: 开发移动端应用
6. **微服务**: 拆分为微服务架构

## 📞 联系方式

- **邮箱**: support@iot-hotel.com
- **电话**: 400-123-4567
- **官网**: https://www.iot-hotel.com

---

**版本**: v2.0.0  
**最后更新**: 2026年4月4日
