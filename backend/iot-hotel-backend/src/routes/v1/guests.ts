import { Router } from 'express';
import * as guestController from '../../controllers/guest.controller';

const router = Router();

router.get('/', guestController.get);
router.get('/:id', guestController.getById);
router.post('/', guestController.create);
router.put('/:id', guestController.update);
router.delete('/:id', guestController.remove);
router.get('/booking/:booking_id', guestController.getByBookingId);

export default router;
