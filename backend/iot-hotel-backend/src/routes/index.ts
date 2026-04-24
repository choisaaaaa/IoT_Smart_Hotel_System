import { Router } from 'express';
import logger from '../utils/logger';
import deviceRouter from './v1/devices';
import userRouter from './v1/users';
import authRouter from './v1/auth';
import hotelRouter from './v1/hotel';
import hotelsRouter from './v1/hotels';
import roomRouter from './v1/rooms';
import roomTypeRouter from './v1/room-types';
import floorRouter from './v1/floors';
import bookingRouter from './v1/bookings';
import paymentRouter from './v1/payments';
import memberRouter from './v1/members';
import couponRouter from './v1/coupons';
import deliveryRouter from './v1/delivery';
import maintenanceRouter from './v1/maintenance';
import reviewRouter from './v1/reviews';
import callRouter from './v1/calls';
import guestRouter from './v1/guests';
import uploadRouter from './v1/upload';
import frequentGuestRouter from './v1/frequent-guests';
import healthRouter from './v1/health';
import aiButlerRouter from './v1/ai-butler';
import priceCalendarRouter from './v1/price-calendar';
import ratePlanRouter from './v1/rate-plans';
import systemConfigRouter from './v1/system-config';
import environmentRouter from './v1/environment';
import knowledgeBaseRouter from './v1/knowledge-base';
import mqttRouter from './v1/mqtt';
import rfidRouter from './v1/rfid';
import favoriteRouter from './v1/favorites';
// 已删除: import deviceAlarmRouter from './v1/device-alarms';
// 已删除: import deviceGroupRouter from './v1/device-groups';
// 已删除: import sceneRouter from './v1/scenes';
// 已删除: import firmwareRouter from './v1/firmware';
// 已删除: import irRemoteRouter from './v1/ir-remote';
import rfidAccessRouter from './v1/rfid-access';
import messageRouter from './v1/messages';

/**
 * 已删除的前端未实现接口路由：
 * - mqtt.ts (MQTT管理)
 * - scenes.ts (场景模式管理)
 * - ir-remote.ts (红外遥控管理)
 * - device-groups.ts (设备分组管理)
 * - device-alarms.ts (设备报警管理)
 * - firmware.ts (固件管理)
 */

const router = Router();

router.use((req, res, next) => {
  logger.info(`路由进入 v1 index: ${req.method} ${req.url}`);
  next();
});

router.use('/devices', deviceRouter);
router.use('/users', userRouter);
router.use('/auth', authRouter);
router.use('/hotel', hotelRouter);
router.use('/hotels', hotelsRouter);
router.use('/rooms', roomRouter);
router.use('/room-types', roomTypeRouter);
router.use('/floors', floorRouter);
router.use('/bookings', bookingRouter);
router.use('/booking', bookingRouter);
router.use('/payments', paymentRouter);
router.use('/members', memberRouter);
router.use('/coupons', couponRouter);
router.use('/delivery', deliveryRouter);
router.use('/maintenance', maintenanceRouter);
router.use('/reviews', reviewRouter);
router.use('/calls', callRouter);
router.use('/guests', guestRouter);
router.use('/upload', uploadRouter);
router.use('/frequent-guests', frequentGuestRouter);
router.use('/health', healthRouter);
router.use('/ai-butler', aiButlerRouter);
router.use('/price-calendar', priceCalendarRouter);
router.use('/rate-plans', ratePlanRouter);
router.use('/system-config', systemConfigRouter);
router.use('/environment', environmentRouter);
router.use('/knowledge-base', knowledgeBaseRouter);
router.use('/mqtt', mqttRouter);
router.use('/rfid', rfidRouter);
router.use('/favorites', favoriteRouter);
// 已删除: router.use('/device-alarms', deviceAlarmRouter);
// 已删除: router.use('/device-groups', deviceGroupRouter);
// 已删除: router.use('/scenes', sceneRouter);
// 已删除: router.use('/firmware', firmwareRouter);
// 已删除: router.use('/ir-remote', irRemoteRouter);
router.use('/rfid-access', rfidAccessRouter);
router.use('/messages', messageRouter);

export default router;
