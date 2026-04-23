import { Router, Request, Response } from 'express';
import { successResponse } from '../../types';
import guests from './guests';
import hotels from './hotels';
import hotel from './hotel';
import auth from './auth';
import bookings from './bookings';
import rooms from './rooms';
import payments from './payments';
import members from './members';
import coupons from './coupons';
import delivery from './delivery';
import maintenance from './maintenance';
import reviews from './reviews';
import calls from './calls';
import devices from './devices';
import users from './users';
import upload from './upload';
import aiButler from './ai-butler';
import environment from './environment';
import roomTypes from './room-types';
import priceCalendar from './price-calendar';
import ratePlans from './rate-plans';
import knowledgeBase from './knowledge-base';
import rfid from './rfid';
import rfidAccess from './rfid-access';
import floors from './floors';
import frequentGuests from './frequent-guests';
import health from './health';
import systemConfig from './system-config';

/**
 * 已删除的前端未实现接口路由：
 * - mqtt.ts (MQTT管理)
 * - scenes.ts (场景模式管理)
 * - ir-remote.ts (红外遥控管理)
 * - device-groups.ts (设备分组管理)
 * - device-alarms.ts (设备报警管理)
 * - firmware.ts (固件管理)
 * - guests.ts (访客管理 - 前端无对应页面)
 */

const router = Router();

router.use('/guests', guests);
router.use('/hotels', hotels);
router.use('/hotel', hotel);
router.use('/auth', auth);
router.use('/bookings', bookings);
router.use('/rooms', rooms);
router.use('/room-types', roomTypes);
router.use('/price-calendar', priceCalendar);
router.use('/rate-plans', ratePlans);
router.use('/payments', payments);
router.use('/members', members);
router.use('/coupons', coupons);
router.use('/delivery', delivery);
router.use('/maintenance', maintenance);
router.use('/reviews', reviews);
router.use('/calls', calls);
router.use('/devices', devices);
// 已删除: router.use('/device-groups', deviceGroups);
// 已删除: router.use('/device-alarms', deviceAlarms);
// 已删除: router.use('/ir-remote', irRemote);
// 已删除: router.use('/scenes', scenes);
// 已删除: router.use('/firmware', firmware);
router.use('/users', users);
router.use('/upload', upload);
router.use('/ai-butler', aiButler);
router.use('/environment', environment);
router.use('/knowledge-base', knowledgeBase);
// 已删除: router.use('/mqtt', mqtt);
router.use('/rfid', rfid);
router.use('/rfid-access', rfidAccess);
router.use('/floors', floors);
router.use('/frequent-guests', frequentGuests);
router.use('/health', health);
router.use('/system-config', systemConfig);

router.get('/', (_req: Request, res: Response) => {
  res.json(successResponse({
    devices: '/api/v1/devices',
    users: '/api/v1/users',
    auth: '/api/v1/auth',
    hotels: '/api/v1/hotels',
    rooms: '/api/v1/rooms',
    bookings: '/api/v1/bookings',
    payments: '/api/v1/payments',
    members: '/api/v1/members',
    coupons: '/api/v1/coupons',
    delivery: '/api/v1/delivery',
    maintenance: '/api/v1/maintenance',
    reviews: '/api/v1/reviews',
    calls: '/api/v1/calls',
    guests: '/api/v1/guests',
    environment: '/api/v1/environment',
    'ai-butler': '/api/v1/ai-butler',
    rfid: '/api/v1/rfid',
    floors: '/api/v1/floors'
  }, '慧宿智联智能酒店系统 API v1.0'));
});

export default router;
