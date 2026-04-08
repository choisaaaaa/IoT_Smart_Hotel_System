import { Router } from 'express';
import { list, detail, create, update, remove, updatePassword } from '../../controllers/user.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, authorize(['admin', 'system']), list);
router.get('/:id', authenticate as any, authorize(['admin', 'system']), detail);
router.post('/', authenticate as any, authorize(['admin', 'system']), create);
router.put('/:id', authenticate as any, authorize(['admin', 'system']), update);
router.delete('/:id', authenticate as any, authorize(['admin', 'system']), remove);
router.put('/:id/password', authenticate as any, authorize(['admin', 'system']), updatePassword);

export default router;
