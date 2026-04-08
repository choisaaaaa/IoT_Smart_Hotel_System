import { Router } from 'express';
import { UploadController } from '../../controllers/upload.controller';
import { upload } from '../../utils/upload';
import { authenticate } from '../../middleware/auth';

const router = Router();

// 上传图片接口，需要认证
router.post('/image', authenticate as any, upload.single('image'), UploadController.uploadImage);

export default router;
