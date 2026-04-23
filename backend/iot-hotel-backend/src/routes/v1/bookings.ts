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
 * /bookings:
 *   get:
 *     summary: 获取预订列表
 *     tags: [Bookings]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
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
router.get('/lookup', bookingController.lookupForGuest);
router.get('/my', authenticate as any, bookingController.getMyBookings);
router.get('/calculate-price', authenticate, bookingController.getCalculatedPrice);
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
router.post('/:id/checkin-online', bookingController.checkinOnline);


router.post('/test', (req, res) => res.json({ message: 'test ok' }));
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.create);
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
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.get);
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
router.put('/:id/reject-pre-checkin', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), bookingController.rejectPreCheckin);
router.put('/:id/checkout', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.checkout);

router.put('/:id/cancel', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.cancel);
router.put('/:id/extend', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.extendStay);
router.post('/:id/extend-price', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), bookingController.calculateExtendPrice);
router.patch('/:id/status', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), bookingController.updateStatus);

export default router;
