import swaggerJsdoc from 'swagger-jsdoc';
import appConfig from './app';

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: '慧宿智联·云边端一体化智能酒店物联网系统 API',
      version: '2.2.0',
      description: '智能酒店物联网设备管理与服务全栈解决方案后端接口文档。\n\n' +
                   '### 系统特性\n' +
                   '- **云边端一体化**：支持云端调度与边缘侧实时响应。\n' +
                   '- **多租户架构**：支持多酒店、多门店隔离管理。\n' +
                   '- **实时交互**：部分实时状态通过 WebSocket 推送（端口同 API 端口）。\n' +
                   '- **安全保障**：全量接口支持 JWT 认证与角色权限校验。',
      contact: {
        name: '慧宿智联团队',
      },
    },
    servers: [
      {
        url: `http://localhost:${process.env.PORT || 3000}${appConfig.apiPrefix}`,
        description: '本地开发服务器',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        ApiResponse: {
          type: 'object',
          properties: {
            code: { type: 'integer', example: 200 },
            message: { type: 'string', example: 'success' },
            data: { type: 'object' },
            timestamp: { type: 'number', example: 1714022400000 },
          },
        },
        ApiError: {
          type: 'object',
          properties: {
            code: { type: 'integer', example: 400 },
            message: { type: 'string', example: '请求参数错误' },
            details: { type: 'object' },
            timestamp: { type: 'number', example: 1714022400000 },
          },
        },
        Hotel: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            hotel_name: { type: 'string' },
            hotel_address: { type: 'string' },
            hotel_phone: { type: 'string' },
            star_rating: { type: 'integer' },
          },
        },
        Room: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            room_number: { type: 'string' },
            room_type_id: { type: 'integer' },
            status: { type: 'string', enum: ['available', 'occupied', 'dirty', 'maintenance'] },
          },
        },
        Device: {
          type: 'object',
          properties: {
            device_id: { type: 'string' },
            device_name: { type: 'string' },
            device_type: { type: 'string' },
            room_id: { type: 'integer' },
            is_online: { type: 'boolean' },
          },
        },
        User: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            username: { type: 'string' },
            phone: { type: 'string' },
            role: { type: 'string' },
            hotel_id: { type: 'integer' },
          },
        },
        Booking: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            hotel_id: { type: 'integer' },
            room_id: { type: 'integer' },
            guest_name: { type: 'string' },
            check_in: { type: 'string', format: 'date' },
            check_out: { type: 'string', format: 'date' },
            status: { type: 'string' },
          },
        },
        Payment: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            booking_id: { type: 'integer' },
            amount: { type: 'number' },
            payment_method: { type: 'string' },
            status: { type: 'string' },
            transaction_id: { type: 'string' },
          },
        },
        Maintenance: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            room_id: { type: 'integer' },
            title: { type: 'string' },
            description: { type: 'string' },
            status: { type: 'string' },
            priority: { type: 'string' },
          },
        },
        Review: {
          type: 'object',
          properties: {
            id: { type: 'integer' },
            booking_id: { type: 'integer' },
            user_id: { type: 'integer' },
            rating: { type: 'integer' },
            content: { type: 'string' },
            reply: { type: 'string' },
          },
        },
      },
    },
    security: [
      {
        bearerAuth: [],
      },
    ],
  },
  apis: ['./src/routes/**/*.ts', './src/controllers/**/*.ts'], // 扫描路由和控制器中的注解
};

const swaggerSpec = swaggerJsdoc(options);

export default swaggerSpec;
