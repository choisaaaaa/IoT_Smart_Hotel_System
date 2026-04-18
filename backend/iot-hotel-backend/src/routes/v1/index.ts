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
import mqtt from './mqtt';
import rfid from './rfid';
import floors from './floors';
import frequentGuests from './frequent-guests';
import health from './health';
import systemConfig from './system-config';

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
router.use('/users', users);
router.use('/upload', upload);
router.use('/ai-butler', aiButler);
router.use('/environment', environment);
router.use('/knowledge-base', knowledgeBase);
router.use('/mqtt', mqtt);
router.use('/rfid', rfid);
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
    guests: '/api/v1/guests'
  }));
});

export default router;
