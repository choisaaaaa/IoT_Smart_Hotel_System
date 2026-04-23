import { Router } from 'express';
import { UploadController } from '../../controllers/upload.controller';
import { upload } from '../../utils/upload';
import { authenticate } from '../../middleware/auth';

/**
 * @swagger
 * tags:
 *   name: Upload
 *   description: 文件与图片上传接口
 */

const router = Router();

/**
 * @swagger
 * /upload/image:
 *   post:
 *     summary: 上传图片文件
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               image:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: 上传成功，返回图片URL
 */
// 上传图片接口，需要认证
router.post('/image', authenticate as any, upload.single('image'), UploadController.uploadImage);


export default router;
