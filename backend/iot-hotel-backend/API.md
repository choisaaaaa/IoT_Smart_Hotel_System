# 智慧酒店物联网控制系统 - API 文档

**版本**: v3.4.0  
**最后更新**: 2026年4月16日

---

## 📋 目录

1. [接口规范](#接口规范)
2. [酒店管理接口](#酒店管理接口)
3. [酒店图片管理接口](#酒店图片管理接口)
4. [评价管理接口](#评价管理接口)
5. [AI知识库接口](#ai知识库接口)
6. [会员管理接口](#会员管理接口)
7. [其他接口](#其他接口)

---

## 接口规范

### 基地址

```
http://localhost:3000/api/v1
```

### 认证方式

除健康检查接口外，所有接口需要在请求头中携带 JWT Token：

```
Authorization: Bearer <token>
```

### 响应格式

```json
{
  "code": 200,
  "message": "success",
  "data": { }
}
```

### 错误码

| 错误码 | 说明 |
|--------|------|
| 200 | 成功 |
| 400 | 请求参数错误 |
| 401 | 未授权/Token无效 |
| 403 | 无权限访问 |
| 404 | 资源不存在 |
| 500 | 服务器内部错误 |

---

## 酒店管理接口

### 获取酒店详情（带图片列表）

```http
GET /hotels/:hotelId/detail
```

**参数说明**:
- `hotelId` - 酒店ID (路径参数)

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "hotel": {
      "id": 1,
      "hotel_name": "智联酒店旗舰店",
      "hotel_address": "北京市朝阳区xxx路xxx号",
      "hotel_phone": "010-12345678",
      "hotel_star": 5,
      "description": "智慧物联网样板店",
      "city": "北京",
      "location": "朝阳区CBD商圈",
      "logo": "/uploads/logo.png",
      "image_url": "/uploads/cover.jpg",
      "promotion": "新店开业8折优惠"
    },
    "images": [
      {
        "id": 1,
        "image_url": "/uploads/hotel/1.jpg",
        "image_type": "cover",
        "sort_order": 0
      }
    ]
  }
}
```

### 更新酒店信息

```http
PUT /hotels/:hotelId
```

**请求体**:
```json
{
  "hotel_name": "智联酒店旗舰店",
  "hotel_address": "北京市朝阳区xxx路xxx号",
  "hotel_phone": "010-12345678",
  "hotel_star": 5,
  "city": "北京",
  "location": "朝阳区CBD商圈",
  "description": "酒店简介",
  "logo": "/uploads/logo.png",
  "image_url": "/uploads/cover.jpg",
  "promotion": "促销信息"
}
```

**权限**: 酒店管理员、系统管理员

---

## 酒店图片管理接口

### 获取酒店图片列表

```http
GET /hotels/:hotelId/images
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "images": [
      {
        "id": 1,
        "image_url": "/uploads/hotel/1.jpg",
        "image_type": "gallery",
        "sort_order": 0,
        "is_active": 1,
        "created_at": "2026-04-16T10:00:00Z"
      }
    ]
  }
}
```

### 添加酒店图片

```http
POST /hotels/:hotelId/images
```

**请求体**:
```json
{
  "image_url": "/uploads/hotel/2.jpg",
  "image_type": "gallery",
  "sort_order": 1
}
```

**参数说明**:
- `image_url` (必填) - 图片URL
- `image_type` (可选) - 图片类型: `cover`(封面), `gallery`(相册), `room`(房型)，默认 `gallery`
- `sort_order` (可选) - 排序顺序，默认 0

**权限**: 酒店管理员、系统管理员

### 更新酒店图片

```http
PUT /hotels/:hotelId/images/:imageId
```

**请求体**:
```json
{
  "image_type": "cover",
  "sort_order": 0,
  "is_active": 1
}
```

**权限**: 酒店管理员、系统管理员

### 删除酒店图片

```http
DELETE /hotels/:hotelId/images/:imageId
```

**权限**: 酒店管理员、系统管理员

---

## 评价管理接口

### 获取评价列表

```http
GET /reviews
```

**查询参数**:
- `hotel_id` - 酒店ID (酒店管理员必填)
- `score` - 评分筛选 (1-5)
- `page` - 页码，默认 1
- `pageSize` - 每页数量，默认 10

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "list": [
      {
        "id": 1,
        "score": 5,
        "environment_rating": 5,
        "facility_rating": 5,
        "comfort_rating": 5,
        "content": "非常满意的一次入住体验！",
        "photos": ["/uploads/review/1.jpg"],
        "reply": "感谢您的评价，期待再次光临！",
        "replied_at": "2026-04-16T12:00:00Z",
        "member_name": "张三",
        "user_avatar": "/uploads/avatar/1.jpg",
        "created_at": "2026-04-16T10:00:00Z"
      }
    ],
    "total": 100
  }
}
```

### 获取评价详情

```http
GET /reviews/:id
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": 1,
    "order_id": 1001,
    "hotel_id": 1,
    "room_type_name": "豪华大床房",
    "score": 5,
    "content": "非常满意！",
    "photos": [],
    "reply": null,
    "member_name": "张三",
    "member_phone": "138****8888",
    "user_avatar": "/uploads/avatar/1.jpg",
    "created_at": "2026-04-16T10:00:00Z"
  }
}
```

### 回复评价

```http
POST /reviews/:id/reply
```

**请求体**:
```json
{
  "reply": "感谢您的评价，期待再次光临！"
}
```

**权限**: 酒店管理员、系统管理员

### 删除评价

```http
DELETE /reviews/:id
```

**权限**: 酒店管理员、系统管理员

### 获取评价统计

```http
GET /reviews/stats
```

**查询参数**:
- `hotel_id` - 酒店ID

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "total_reviews": 100,
    "avg_score": 4.5,
    "good_count": 80,
    "bad_count": 5
  }
}
```

---

## AI知识库接口

### 获取知识库词条列表

```http
GET /ai-knowledge
```

**查询参数**:
- `hotel_id` - 酒店ID (0表示全局词条)
- `category` - 分类筛选
- `keyword` - 关键词搜索
- `page` - 页码
- `pageSize` - 每页数量

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "list": [
      {
        "id": 1,
        "category": "hotel_info",
        "question": "酒店的早餐时间是？",
        "answer": "早餐时间为早上7:00-10:00，位于一楼餐厅。",
        "keywords": ["早餐", "时间"],
        "priority": 10,
        "is_active": 1
      }
    ],
    "total": 50
  }
}
```

### 创建知识库词条

```http
POST /ai-knowledge
```

**请求体**:
```json
{
  "hotel_id": 1,
  "category": "hotel_info",
  "question": "酒店的早餐时间是？",
  "answer": "早餐时间为早上7:00-10:00。",
  "keywords": ["早餐", "时间"],
  "priority": 10
}
```

**参数说明**:
- `category` - 分类: `hotel_info`(酒店信息), `service`(服务设施), `policy`(政策规定), `faq`(常见问题), `other`(其他)
- `priority` - 优先级，数值越大越优先

### 更新知识库词条

```http
PUT /ai-knowledge/:id
```

**请求体**:
```json
{
  "question": "酒店的早餐时间是？",
  "answer": "早餐时间为早上7:00-10:30。",
  "is_active": 1
}
```

### 删除知识库词条

```http
DELETE /ai-knowledge/:id
```

---

## 会员管理接口

### 获取会员资产

```http
GET /members/me
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": 1,
    "phone": "13800138000",
    "name": "张三",
    "member_level": "silver",
    "level": 2,
    "level_label": "银会员",
    "experience": 150,
    "points": 500,
    "balance": 100.00,
    "coupons_count": 3,
    "level_discounts": {
      "standard": 1.0,
      "silver": 0.95,
      "gold": 0.9
    },
    "level_multipliers": {
      "standard": 1,
      "silver": 5,
      "gold": 10
    }
  }
}
```

---

## 其他接口

### 上传图片

```http
POST /upload/image
```

**Content-Type**: `multipart/form-data`

**请求参数**:
- `image` (file) - 图片文件

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "url": "/uploads/2026/04/16/xxx.jpg"
  }
}
```

### 健康检查

```http
GET /health
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "status": "ok",
    "timestamp": "2026-04-16T10:00:00Z"
  }
}
```

---

## 数据库表结构

### 新增表 (v3.4.0)

#### hotel_images - 酒店图片表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| hotel_id | INT | 酒店ID |
| image_url | VARCHAR(500) | 图片URL |
| image_type | VARCHAR(20) | 图片类型 |
| sort_order | INT | 排序顺序 |
| is_active | TINYINT | 是否启用 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

#### ai_knowledge_entries - AI知识库词条表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| hotel_id | INT | 酒店ID (0=全局) |
| category | VARCHAR(50) | 分类 |
| question | TEXT | 问题 |
| answer | TEXT | 答案 |
| keywords | JSON | 关键词 |
| priority | INT | 优先级 |
| is_active | TINYINT | 是否启用 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

#### ai_conversations - AI对话历史表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| session_id | VARCHAR(64) | 会话ID |
| user_id | INT | 用户ID |
| hotel_id | INT | 酒店ID |
| message | TEXT | 消息内容 |
| role | ENUM | 角色 |
| intent | VARCHAR(50) | 意图 |
| created_at | DATETIME | 创建时间 |

---

## 更新日志

### v3.4.0 (2026-04-16)

- 新增酒店图片管理接口
- 新增评价管理接口（支持头像显示）
- 新增AI知识库接口
- 更新会员资产接口（返回动态会员方案）

### v3.3.0 (2026-04-15)

- 新增酒店门店照片管理功能

### v3.2.0 (2026-04-15)

- 新增评价系统用户头像支持

### v3.0.0 (2026-04-14)

- 新增AI知识库表结构

---

**文档维护**: 后端开发团队  
**问题反馈**: support@iot-hotel.com
