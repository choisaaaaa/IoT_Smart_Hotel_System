import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { v4 as uuidv4 } from 'uuid';
import logger from './logger';

// 允许的图片MIME类型
const ALLOWED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp'
];

// 允许的文件扩展名
const ALLOWED_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

// 最大文件大小 (5MB)
const MAX_FILE_SIZE = 5 * 1024 * 1024;

// 上传目录
const uploadDir = path.join(process.cwd(), 'public/uploads');

/**
 * 确保上传目录存在并设置安全权限
 */
function ensureUploadDir(): void {
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
    // 设置目录权限为755 (仅所有者可写)
    fs.chmodSync(uploadDir, 0o755);
  }
}

ensureUploadDir();

/**
 * 验证文件扩展名
 */
function isValidExtension(filename: string): boolean {
  const ext = path.extname(filename).toLowerCase();
  return ALLOWED_EXTENSIONS.includes(ext);
}

/**
 * 验证文件名（防止路径遍历）
 */
function sanitizeFilename(filename: string): string {
  // 移除路径分隔符和非法字符
  return filename
    .replace(/[\\/:*?"<>|]/g, '')
    .replace(/\.{2,}/g, '.')
    .trim();
}

/**
 * 生成安全的文件名
 */
function generateSafeFilename(originalname: string): string {
  const ext = path.extname(originalname).toLowerCase();
  const uuid = uuidv4().replace(/-/g, '');
  return `${uuid}${ext}`;
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    // 验证目录路径
    const resolvedPath = path.resolve(uploadDir);
    const cwd = path.resolve(process.cwd(), 'public/uploads');
    
    if (!resolvedPath.startsWith(cwd)) {
      logger.error(`非法上传路径: ${resolvedPath}`);
      return cb(new Error('非法上传路径'), '');
    }
    
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const safeFilename = generateSafeFilename(file.originalname);
    cb(null, safeFilename);
  }
});

const fileFilter = (req: any, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  // 验证MIME类型
  if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    logger.warn(`拒绝上传: 不支持的MIME类型 ${file.mimetype}`);
    return cb(new Error('不支持的文件类型，仅允许 JPEG, PNG, GIF 和 WEBP 格式'));
  }
  
  // 验证文件扩展名
  if (!isValidExtension(file.originalname)) {
    logger.warn(`拒绝上传: 不支持的文件扩展名 ${file.originalname}`);
    return cb(new Error('不支持的文件扩展名'));
  }
  
  // 验证文件名长度
  if (file.originalname.length > 255) {
    logger.warn(`拒绝上传: 文件名过长`);
    return cb(new Error('文件名过长'));
  }
  
  cb(null, true);
};

/**
 * 基础上传配置
 */
export const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: 1, // 每次只允许上传1个文件
    fields: 10, // 最多10个非文件字段
    parts: 11 // 总共最多11个部分（1文件+10字段）
  }
});

/**
 * 多文件上传配置（用于批量上传）
 * @param maxCount 最大文件数量
 */
export function createMultiUpload(maxCount: number = 5) {
  return multer({
    storage,
    fileFilter,
    limits: {
      fileSize: MAX_FILE_SIZE,
      files: maxCount,
      fields: 10
    }
  });
}

/**
 * 验证上传后的文件
 */
export function validateUploadedFile(file: Express.Multer.File): { valid: boolean; error?: string } {
  // 检查文件是否存在
  if (!file || !file.path) {
    return { valid: false, error: '文件不存在' };
  }
  
  // 检查文件大小
  if (file.size > MAX_FILE_SIZE) {
    fs.unlinkSync(file.path);
    return { valid: false, error: '文件大小超过限制' };
  }
  
  // 检查文件路径（防止路径遍历）
  const resolvedPath = path.resolve(file.path);
  const uploadPath = path.resolve(uploadDir);
  
  if (!resolvedPath.startsWith(uploadPath)) {
    fs.unlinkSync(file.path);
    logger.error(`非法文件路径: ${resolvedPath}`);
    return { valid: false, error: '非法文件路径' };
  }
  
  // 检查文件是否可读
  try {
    fs.accessSync(file.path, fs.constants.R_OK);
  } catch {
    return { valid: false, error: '文件不可读' };
  }
  
  return { valid: true };
}

/**
 * 删除上传的文件
 */
export function deleteUploadedFile(filename: string): boolean {
  try {
    const filePath = path.join(uploadDir, path.basename(filename));
    const resolvedPath = path.resolve(filePath);
    const uploadPath = path.resolve(uploadDir);
    
    // 防止路径遍历
    if (!resolvedPath.startsWith(uploadPath)) {
      logger.error(`尝试删除非法路径: ${resolvedPath}`);
      return false;
    }
    
    if (fs.existsSync(resolvedPath)) {
      fs.unlinkSync(resolvedPath);
      logger.info(`已删除文件: ${filename}`);
      return true;
    }
    return false;
  } catch (error) {
    logger.error(`删除文件失败: ${filename}`, error);
    return false;
  }
}

/**
 * 获取文件URL
 */
export function getFileUrl(filename: string): string {
  return `/uploads/${path.basename(filename)}`;
}
