import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { systemConfigService } from '../services/system-config.service';

/**
 * 获取所有系统配置
 */
export const getAllConfigs = async (req: Request, res: Response) => {
  try {
    const [rows] = await pool.query<RowDataPacket[]>('SELECT config_key, config_value, description FROM system_settings');
    const configs: Record<string, any> = {};
    rows.forEach(row => {
      try {
        // 尝试解析 JSON 格式的配置项
        if (row.config_value && (row.config_value.startsWith('[') || row.config_value.startsWith('{'))) {
          configs[row.config_key] = JSON.parse(row.config_value);
        } else {
          configs[row.config_key] = row.config_value;
        }
      } catch (e) {
        configs[row.config_key] = row.config_value;
      }
    });
    
    // 如果没有会员方案配置，提供默认值
    if (!configs.member_scheme) {
      const defaultScheme = [
        { key: 'standard', name: '普通会员', discount: 1.0, points_multiplier: 1, min_experience: 0, color: '#4b6cb7', benefits: '基础入住权益' },
        { key: 'silver', name: '银卡会员', discount: 0.95, points_multiplier: 5, min_experience: 100, color: '#bdc3c7', benefits: '延迟退房1小时, 免费饮品' },
        { key: 'gold', name: '金卡会员', discount: 0.88, points_multiplier: 9, min_experience: 500, color: '#d4af37', benefits: '延迟退房2小时, 欢迎水果, 早餐8折' },
        { key: 'platinum', name: '铂金会员', discount: 0.85, points_multiplier: 12, min_experience: 2000, color: '#e5e4e2', benefits: '客房升级, 免费早餐, 延迟退房4小时' },
        { key: 'diamond', name: '钻石会员', discount: 0.80, points_multiplier: 15, min_experience: 5000, color: '#30cfd0', benefits: '行政酒廊待遇, 全免早餐, 极速退房' }
      ];
      configs.member_scheme = defaultScheme;
      // 异步保存到数据库，不影响本次返回
      pool.query('INSERT IGNORE INTO system_settings (config_key, config_value, description) VALUES (?, ?, ?)', 
        ['member_scheme', JSON.stringify(defaultScheme), '会员等级方案配置']);
    }

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
      if (key === 'member_program_name') {return res.json(successResponse('IOT', '获取默认配置成功'));}
      return res.status(404).json(errorResponse('配置项不存在'));
    }
    
    res.json(successResponse(rows[0].config_value, '获取系统配置成功'));
  } catch (error) {
    // 降级处理
    if (req.params.key === 'member_program_name') {return res.json(successResponse('IOT', '获取默认配置成功'));}
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
      const stringValue = typeof value === 'object' ? JSON.stringify(value) : String(value);
      await pool.query(
        'INSERT INTO system_settings (config_key, config_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE config_value = ?, updated_at = CURRENT_TIMESTAMP',
        [key, stringValue, stringValue]
      );
    }
    
    // 清除配置缓存
    systemConfigService.clearCache();
    
    res.json(successResponse(null, '更新系统配置成功'));
  } catch (error) {
    logger.error('更新系统配置失败:', error.message);
    res.status(500).json(errorResponse('更新系统配置失败'));
  }
};
