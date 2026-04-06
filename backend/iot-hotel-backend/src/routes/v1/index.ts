import { Router, Request, Response } from 'express';
import { successResponse } from '../../types';
import guests from './guests';

const router = Router();

router.use('/guests', guests);

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
    guests: '/api/v1/guests'
  }));
});

export default router;
