import { Request, Response } from 'express';
import { successResponse, errorResponse } from '../types';
import logger from '../utils/logger';
import config from '../config';

export class UploadController {
  static async uploadImage(req: Request, res: Response) {
    try {
      const file = (req as any).file;

      if (!file) {
        return res.status(400).json(errorResponse('请选择要上传的图片'));
      }

      // 数据库仅存储相对路径 (以 uploads/ 开头)，由前端根据 BaseURL 渲染
      const relativePath = `/uploads/${file.filename}`;
      
      res.json(successResponse({
        url: relativePath,
        filename: file.filename,
        mimetype: file.mimetype,
        size: file.size
      }, '图片上传成功'));
    } catch (error: any) {
      logger.error('图片上传失败:', error.message);
      res.status(500).json(errorResponse('图片上传失败'));
    }
  }
}
