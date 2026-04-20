import express from 'express';
import * as systemConfigController from '../../controllers/system-config.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = express.Router();

router.get('/:key', authenticate as any, systemConfigController.getConfigByKey);
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), systemConfigController.getAllConfigs);
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]) as any, systemConfigController.updateConfigs);

export default router;
