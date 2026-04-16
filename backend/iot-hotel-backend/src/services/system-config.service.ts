import pool, { RowDataPacket } from '../config/database';
import logger from '../utils/logger';
import { LEVEL_DISCOUNTS, LEVEL_POINTS_MULTIPLIER } from '../config/constants';

export interface MemberLevelConfig {
  key: string;
  name: string;
  discount: number;
  points_multiplier: number;
  min_experience: number;
  color: string;
  benefits: string;
}

export class SystemConfigService {
  private static instance: SystemConfigService;
  private cache: Map<string, any> = new Map();
  private lastFetch: number = 0;
  private CACHE_TTL = 60 * 1000; // 1 minute cache

  private constructor() {}

  public static getInstance(): SystemConfigService {
    if (!SystemConfigService.instance) {
      SystemConfigService.instance = new SystemConfigService();
    }
    return SystemConfigService.instance;
  }

  async getMemberScheme(): Promise<MemberLevelConfig[]> {
    const now = Date.now();
    if (this.cache.has('member_scheme') && (now - this.lastFetch < this.CACHE_TTL)) {
      return this.cache.get('member_scheme');
    }

    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT config_value FROM system_settings WHERE config_key = "member_scheme"'
      );

      if (rows.length > 0) {
        const scheme = JSON.parse(rows[0].config_value);
        this.cache.set('member_scheme', scheme);
        this.lastFetch = now;
        return scheme;
      }
    } catch (e) {
      logger.error('获取会员方案失败:', e);
    }

    // Fallback to defaults
    const defaultScheme: MemberLevelConfig[] = [
      { key: 'standard', name: '普通会员', discount: LEVEL_DISCOUNTS['standard'] || 1.0, points_multiplier: LEVEL_POINTS_MULTIPLIER['standard'] || 1, min_experience: 0, color: '#4b6cb7', benefits: '基础入住权益' },
      { key: 'silver', name: '银卡会员', discount: LEVEL_DISCOUNTS['silver'] || 0.95, points_multiplier: LEVEL_POINTS_MULTIPLIER['silver'] || 3, min_experience: 100, color: '#bdc3c7', benefits: '延迟退房1小时, 免费饮品' },
      { key: 'gold', name: '金卡会员', discount: LEVEL_DISCOUNTS['gold'] || 0.88, points_multiplier: LEVEL_POINTS_MULTIPLIER['gold'] || 9, min_experience: 500, color: '#d4af37', benefits: '延迟退房2小时, 欢迎水果, 早餐8折' },
      { key: 'platinum', name: '铂金会员', discount: LEVEL_DISCOUNTS['platinum'] || 0.85, points_multiplier: LEVEL_POINTS_MULTIPLIER['platinum'] || 12, min_experience: 2000, color: '#e5e4e2', benefits: '客房升级, 免费早餐, 延迟退房4小时' },
      { key: 'diamond', name: '钻石会员', discount: LEVEL_DISCOUNTS['diamond'] || 0.80, points_multiplier: LEVEL_POINTS_MULTIPLIER['diamond'] || 15, min_experience: 5000, color: '#30cfd0', benefits: '行政酒廊待遇, 全免早餐, 极速退房' }
    ];
    return defaultScheme;
  }

  async getLevelConfig(levelKey: string): Promise<MemberLevelConfig | undefined> {
    const scheme = await this.getMemberScheme();
    return scheme.find(s => s.key === levelKey.toLowerCase().trim());
  }

  /**
   * 根据经验值计算当前应有的会员等级
   */
  async calculateLevel(experience: number): Promise<string> {
    const scheme = await this.getMemberScheme();
    const exp = Number(experience || 0);

    if (scheme && scheme.length > 0) {
      // 按门槛从高到低排序，找到符合条件的最高等级
      const sortedScheme = [...scheme].sort((a, b) => (Number(b.min_experience) || 0) - (Number(a.min_experience) || 0));
      const match = sortedScheme.find(s => exp >= (Number(s.min_experience) || 0));
      return match ? match.key : 'standard';
    }

    // 降级硬编码逻辑
    if (exp >= 5000) {return 'diamond';}
    if (exp >= 2000) {return 'platinum';}
    if (exp >= 500) {return 'gold';}
    if (exp >= 100) {return 'silver';}
    return 'standard';
  }

  /**
   * 获取成长值倍率 (1元 = X成长值)
   */
  async getExpRate(): Promise<number> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT config_value FROM system_settings WHERE config_key = "exp_rate"'
      );
      if (rows.length > 0) {
        return Number(rows[0].config_value) || 0.1; // 默认 0.1 (10元=1点)
      }
    } catch (e) {
      logger.error('获取成长值倍率失败:', e);
    }
    return 0.1;
  }

  /**
   * 获取积分倍率 (1元 = X积分)
   */
  async getPointsRate(): Promise<number> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT config_value FROM system_settings WHERE config_key = "points_rate"'
      );
      if (rows.length > 0) {
        return Number(rows[0].config_value) || 10; // 默认 10
      }
    } catch (e) {
      logger.error('获取积分倍率失败:', e);
    }
    return 10;
  }

  /**
   * 获取积分抵扣倍率 (X积分 = 1元)
   */
  async getPointsRedeemRate(): Promise<number> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT config_value FROM system_settings WHERE config_key = "points_redeem_rate"'
      );
      if (rows.length > 0) {
        return Number(rows[0].config_value) || 10;
      }
    } catch (e) {
      logger.error('获取积分抵扣倍率失败:', e);
    }
    return 10;
  }

  /**
   * 获取签到奖励积分
   */
  async getCheckinPoints(): Promise<number> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT config_value FROM system_settings WHERE config_key = "checkin_points"'
      );
      if (rows.length > 0) {
        return Number(rows[0].config_value) || 50;
      }
    } catch (e) {
      logger.error('获取签到积分配置失败:', e);
    }
    return 50;
  }

  /**
   * 获取签到奖励成长值
   */
  async getCheckinExp(): Promise<number> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT config_value FROM system_settings WHERE config_key = "checkin_exp"'
      );
      if (rows.length > 0) {
        return Number(rows[0].config_value) || 10;
      }
    } catch (e) {
      logger.error('获取签到成长值配置失败:', e);
    }
    return 10;
  }

  clearCache() {
    this.cache.clear();
    this.lastFetch = 0;
  }
}

export const systemConfigService = SystemConfigService.getInstance();
