import { Router } from 'express';
import { list, detail, create, update, remove, updatePassword } from '../../controllers/user.controller';

const router = Router();

router.get('/', list);
router.get('/:id', detail);
router.post('/', create);
router.put('/:id', update);
router.delete('/:id', remove);
router.put('/:id/password', updatePassword);

export default router;
