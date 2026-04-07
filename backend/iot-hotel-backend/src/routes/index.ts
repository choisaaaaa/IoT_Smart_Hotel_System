import { Router } from 'express';
import deviceRouter from './v1/devices';
import userRouter from './v1/users';
import authRouter from './v1/auth';
import hotelRouter from './v1/hotels';
import roomRouter from './v1/rooms';
import bookingRouter from './v1/bookings';
import paymentRouter from './v1/payments';
import memberRouter from './v1/members';
import couponRouter from './v1/coupons';
import deliveryRouter from './v1/delivery';
import maintenanceRouter from './v1/maintenance';
import reviewRouter from './v1/reviews';
import callRouter from './v1/calls';
import guestRouter from './v1/guests';
import healthRouter from './v1/health';

const router = Router();

router.use('/devices', deviceRouter);
router.use('/users', userRouter);
router.use('/auth', authRouter);
router.use('/hotels', hotelRouter);
router.use('/rooms', roomRouter);
router.use('/bookings', bookingRouter);
router.use('/payments', paymentRouter);
router.use('/members', memberRouter);
router.use('/coupons', couponRouter);
router.use('/delivery', deliveryRouter);
router.use('/maintenance', maintenanceRouter);
router.use('/reviews', reviewRouter);
router.use('/calls', callRouter);
router.use('/guests', guestRouter);
router.use('/health', healthRouter);

export default router;
