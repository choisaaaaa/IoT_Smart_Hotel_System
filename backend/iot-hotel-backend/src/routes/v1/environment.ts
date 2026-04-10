import { Router } from 'express';
import environmentController from '../../controllers/environment.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, authorize(['admin', 'manager', 'staff', 'system']), environmentController.getEnvironmentData);

router.get('/history', authenticate as any, authorize(['admin', 'manager', 'staff', 'system']), environmentController.getEnvironmentHistory);

router.get('/fire-alarms', authenticate as any, authorize(['admin', 'manager', 'staff', 'system']), environmentController.getFireAlarms);

router.put('/fire-alarms/:id/acknowledge', authenticate as any, authorize(['admin', 'manager', 'staff']), environmentController.acknowledgeAlarm);

router.put('/fire-alarms/:id/resolve', authenticate as any, authorize(['admin', 'manager', 'staff']), environmentController.resolveAlarm);

router.get('/devices', authenticate as any, authorize(['admin', 'manager', 'staff', 'system']), environmentController.getRoomDevices);

router.post('/devices/:id/control', authenticate as any, authorize(['admin', 'manager', 'staff']), environmentController.controlDevice);

router.get('/energy', authenticate as any, authorize(['admin', 'manager', 'staff', 'system']), environmentController.getEnergyConsumption);

router.get('/event-logs', authenticate as any, authorize(['admin', 'manager', 'staff', 'system']), environmentController.getEventLogs);

router.get('/dashboard', authenticate as any, authorize(['admin', 'manager', 'staff', 'system']), environmentController.getDashboardStats);

export default router;
