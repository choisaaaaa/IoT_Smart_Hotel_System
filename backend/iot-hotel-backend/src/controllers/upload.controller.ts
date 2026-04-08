import { Request, Response } from 'express';
import { successResponse, errorResponse } from '../types';
import logger from '../utils/logger';

export class UploadController {
  static async uploadImage(req: Request, res: Response) {
    try {
      // 使用类型断言来解决 multer 的 file 属性在 Request 中不存在的问题
      const file = (req as any).file;

      if (!file) {
        return res.status(400).json(errorResponse('请选择要上传的图片'));
      }

      const fileUrl = `/uploads/${file.filename}`;
      res.json(successResponse({
        url: fileUrl,
        filename: file.filename,
        mimetype: file.mimetype,
        size: file.size
      }, '图片上传成功'));
    } catch (error: any) {
      logger.error('图片上传失败:', error);
      res.status(500).json(errorResponse('图片上传失败'));
    }
  }
}
