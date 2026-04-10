import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

/**
 * 获取所有系统配置
 */
export const getAllConfigs = async (req: Request, res: Response) => {
  try {
    const [rows] = await pool.query<RowDataPacket[]>('SELECT config_key, config_value, description FROM system_settings');
    const configs: Record<string, any> = {};
    rows.forEach(row => {
      configs[row.config_key] = row.config_value;
    });
    res.json(successResponse(configs, '获取系统配置成功'));
  } catch (error) {
    // 如果表不存在，尝试创建
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS system_settings (
          id INT AUTO_INCREMENT PRIMARY KEY,
          config_key VARCHAR(50) UNIQUE NOT NULL,
          config_value TEXT,
          description VARCHAR(255),
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
      `);
      await pool.query("INSERT IGNORE INTO system_settings (config_key, config_value, description) VALUES ('member_program_name', 'IOT', '会员计划显示名称')");
      res.json(successResponse({ member_program_name: 'IOT' }, '初始化并获取系统配置成功'));
    } catch (e) {
      logger.error('获取或创建系统配置失败:', e);
      res.status(500).json(errorResponse('获取系统配置失败'));
    }
  }
};

/**
 * 获取特定系统配置 (公开)
 */
export const getConfigByKey = async (req: Request, res: Response) => {
  try {
    const { key } = req.params;
    const [rows] = await pool.query<RowDataPacket[]>('SELECT config_value FROM system_settings WHERE config_key = ?', [key]);
    
    if (rows.length === 0) {
      // 默认值
      if (key === 'member_program_name') return res.json(successResponse('IOT', '获取默认配置成功'));
      return res.status(404).json(errorResponse('配置项不存在'));
    }
    
    res.json(successResponse(rows[0].config_value, '获取系统配置成功'));
  } catch (error) {
    // 降级处理
    if (req.params.key === 'member_program_name') return res.json(successResponse('IOT', '获取默认配置成功'));
    res.status(500).json(errorResponse('获取系统配置失败'));
  }
};

/**
 * 更新系统配置 (仅系统管理员)
 */
export const updateConfigs = async (req: AuthRequest, res: Response) => {
  try {
    const configs = req.body; // { key: value, ... }
    
    for (const [key, value] of Object.entries(configs)) {
      await pool.query(
        'INSERT INTO system_settings (config_key, config_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE config_value = ?, updated_at = CURRENT_TIMESTAMP',
        [key, value, value]
      );
    }
    
    res.json(successResponse(null, '更新系统配置成功'));
  } catch (error) {
    logger.error('更新系统配置失败:', error);
    res.status(500).json(errorResponse('更新系统配置失败'));
  }
};
