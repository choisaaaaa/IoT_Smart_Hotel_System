import swaggerJsdoc from 'swagger-jsdoc';
import appConfig from './app';

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: '慧宿智联·云边端一体化智能酒店物联网系统 API',
      version: '2.2.0',
      description: '智能酒店物联网设备管理与服务全栈解决方案后端接口文档',
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
