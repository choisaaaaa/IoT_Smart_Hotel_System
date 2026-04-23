import { Router } from 'express';
import * as bookingController from '../../controllers/booking.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Bookings
 *   description: 预订与入住管理接口
 */

const router = Router();

/**
 * @swagger
 * /bookings/lookup:
 *   get:
 *     summary: 按手机号查询预订（住客自助查询）
 *     tags: [Bookings]
 *     parameters:
 *       - in: query
 *         name: phone
 *         required: true
 *         schema: { type: string }
 *         description: 住客手机号
 *     responses:
 *       200:
 *         description: 成功查询
 */
router.get('/lookup', bookingController.lookupForGuest);

/**
 * @swagger
 * /bookings/my:
 *   get:
 *     summary: 获取当前用户的预订
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功
 */
router.get('/my', authenticate as any, bookingController.getMyBookings);

/**
 * @swagger
 * /bookings/calculate-price:
 *   get:
 *     summary: 计算预订总价
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: room_type_id
 *         required: true
 *         schema: { type: integer }
 *       - in: query
 *         name: check_in
 *         required: true
 *         schema: { type: string, format: date }
 *       - in: query
 *         name: check_out
 *         required: true
 *         schema: { type: string, format: date }
 *     responses:
 *       200:
 *         description: 成功返回总价
 */
router.get('/calculate-price', authenticate, bookingController.getCalculatedPrice);

/**
 * @swagger
 * /bookings/calculate-price:
 *   post:
 *     summary: 计算预订总价(POST方式)
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [room_type_id, check_in, check_out]
 *             properties:
 *               room_type_id: { type: integer }
 *               check_in: { type: string, format: date }
 *               check_out: { type: string, format: date }
 *     responses:
 *       200:
 *         description: 成功返回总价
 */
router.post('/calculate-price', authenticate, bookingController.getCalculatedPrice);

/**
 * @swagger
 * /bookings/checkin-online/{id}:
 *   post:
 *     summary: 在线办理入住
 *     tags: [Bookings]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 办理成功
 */
router.post('/checkin-online/:id', bookingController.checkinOnline);

/**
 * @swagger
 * /bookings/{id}/checkin-online:
 *   post:
 *     summary: 在线办理入住(路径参数方式)
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 办理成功
 */
router.post('/:id/checkin-online', bookingController.checkinOnline);


/**
 * @swagger
 * /bookings/test:
 *   post:
 *     summary: 预订接口测试端点
 *     tags: [Bookings]
 *     responses:
 *       200:
 *         description: 测试通过
 */
router.post('/test', (req, res) => res.json({ message: 'test ok' }));

/**
 * @swagger
 * /bookings:
 *   post:
 *     summary: 创建新预订
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [hotel_id, room_type_id, check_in, check_out, guest_name, guest_phone]
 *             properties:
 *               hotel_id: { type: integer }
 *               room_type_id: { type: integer }
 *               check_in: { type: string, format: date }
 *               check_out: { type: string, format: date }
 *               guest_name: { type: string }
 *               guest_phone: { type: string }
 *     responses:
 *       201:
 *         description: 创建成功
 */
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.create);

/**
 * @swagger
 * /bookings:
 *   get:
 *     summary: 获取预订列表
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.get);

/**
 * @swagger
 * /bookings/{id}:
 *   get:
 *     summary: 获取预订详情
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 成功
 */
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.getById);

/**
 * @swagger
 * /bookings/{id}/confirm:
 *   put:
 *     summary: 确认预订
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 确认成功
 */
router.put('/:id/confirm', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), bookingController.confirm);

/**
 * @swagger
 * /bookings/{id}/checkin:
 *   put:
 *     summary: 办理入住
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 入住成功
 */
router.put('/:id/checkin', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), bookingController.checkin);

/**
 * @swagger
 * /bookings/{id}/checkout:
 *   put:
 *     summary: 办理退房
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 退房成功
 */
router.put('/:id/checkout', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.checkout);

/**
 * @swagger
 * /bookings/{id}/reject-pre-checkin:
 *   put:
 *     summary: 拒绝预入住申请
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 操作成功
 */
router.put('/:id/reject-pre-checkin', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), bookingController.rejectPreCheckin);

/**
 * @swagger
 * /bookings/{id}/extend:
 *   put:
 *     summary: 办理续住
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [new_check_out]
 *             properties:
 *               new_check_out: { type: string, format: date }
 *     responses:
 *       200:
 *         description: 续住成功
 */
router.put('/:id/extend', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.extendStay);

/**
 * @swagger
 * /bookings/{id}/extend-price:
 *   post:
 *     summary: 计算续住价格
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [new_check_out]
 *             properties:
 *               new_check_out: { type: string, format: date }
 *     responses:
 *       200:
 *         description: 成功返回续住价格
 */
router.post('/:id/extend-price', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.calculateExtendPrice);

/**
 * @swagger
 * /bookings/{id}/cancel:
 *   put:
 *     summary: 取消预订
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 取消成功
 */
router.put('/:id/cancel', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.cancel);

/**
 * @swagger
 * /bookings/{id}/status:
 *   patch:
 *     summary: 更新预订状态
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [status]
 *             properties:
 *               status: { type: string }
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.patch('/:id/status', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), bookingController.updateStatus);

export default router;
