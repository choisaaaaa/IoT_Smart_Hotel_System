import { Router } from 'express';

const router = Router();

router.get('/', (_req, res) => {
  res.json({
    code: 200,
    message: '服务正常',
    timestamp: Date.now(),
    version: '2.0.0'
  });
});

export default router;
