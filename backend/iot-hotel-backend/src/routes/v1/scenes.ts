import { Router } from 'express';
import sceneController from '../../controllers/scene.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];
const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER];

router.use(authenticate as any);

router.get('/', authorize(allRoles), sceneController.getAll);
router.get('/executions', authorize(allRoles), sceneController.getExecutions);
router.get('/executions/:id', authorize(allRoles), sceneController.getExecutionById);
router.post('/', authorize(adminRoles), sceneController.create);
router.get('/:id', authorize(allRoles), sceneController.getById);
router.put('/:id', authorize(adminRoles), sceneController.update);
router.delete('/:id', authorize(adminRoles), sceneController.delete);
router.patch('/:id/toggle', authorize(adminRoles), sceneController.toggle);
router.post('/:id/execute', authorize(allRoles), sceneController.execute);
router.post('/init-default', authorize(adminRoles), sceneController.initDefault);

export default router;
