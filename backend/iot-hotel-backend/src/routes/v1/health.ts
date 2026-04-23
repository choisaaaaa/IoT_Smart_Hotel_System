import { Router } from 'express';

/**
 * @swagger
 * tags:
 *   name: System
 *   description: 系统健康检查与状态接口
 */

const router = Router();

/**
 * @swagger
 * /health:
 *   get:
 *     summary: 系统健康检查
 *     tags: [System]
 *     responses:
 *       200:
 *         description: 服务正常
 */
router.get('/', (_req, res) => {

  res.json({
    code: 200,
    message: '服务正常',
    timestamp: Date.now(),
    version: '2.0.0'
  });
});

export default router;
