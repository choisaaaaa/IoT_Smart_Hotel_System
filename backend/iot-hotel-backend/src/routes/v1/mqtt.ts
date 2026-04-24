import express from 'express';
import { MQTTController } from '../../controllers/mqtt.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';
import logger from '../../utils/logger';

const router = express.Router();

router.use((req, res, next) => {
  logger.info(`进入 MQTT Router: ${req.method} ${req.url}`);
  next();
});

// 所有MQTT管理接口都需要系统管理员或酒店管理员权限
router.use(authenticate as any);
router.use(authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]));

// 获取日志
router.get('/logs', MQTTController.getLogs);

// 发送消息
router.post('/send', MQTTController.sendMessage);

// 获取状态
router.get('/status', MQTTController.getStatus);

export default router;
