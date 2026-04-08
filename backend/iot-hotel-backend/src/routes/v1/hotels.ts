import { Router } from 'express';
import { search, detail, roomAvailability } from './hotels.controller';

const router = Router();

router.get('/search', search);
router.get('/:id', detail);
router.get('/:id/rooms/availability', roomAvailability);

export default router;
