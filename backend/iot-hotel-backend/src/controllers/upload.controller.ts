import { Request, Response } from 'express';
import { successResponse, errorResponse } from '../types';
import logger from '../utils/logger';

export class UploadController {
  static async uploadImage(req: Request, res: Response) {
    try {
      if (!req.file) {
        return res.status(400).json(errorResponse('请选择要上传的图片'));
      }

      const fileUrl = `/uploads/${req.file.filename}`;
      res.json(successResponse({
        url: fileUrl,
        filename: req.file.filename,
        mimetype: req.file.mimetype,
        size: req.file.size
      }, '图片上传成功'));
    } catch (error: any) {
      logger.error('图片上传失败:', error);
      res.status(500).json(errorResponse('图片上传失败'));
    }
  }
}
