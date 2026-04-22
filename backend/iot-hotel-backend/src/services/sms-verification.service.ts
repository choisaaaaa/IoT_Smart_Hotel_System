import { randomInt } from 'crypto';
import db from '../config/database';
import logger from '../utils/logger';

interface SMSVerificationConfig {
  enabled: boolean;
  expireMinutes: number;
  resendInterval: number;
  maxAttempts: number;
}

class SMSVerificationService {
  private config: SMSVerificationConfig = {
    enabled: true,
    expireMinutes: 10,
    resendInterval: 60,
    maxAttempts: 5
  };

  constructor() {
    this.loadConfig();
  }

  private async loadConfig() {
    try {
      const [settings]: any = await db.execute(
        'SELECT config_key, config_value FROM system_settings WHERE config_key LIKE ?',
        ['sms_verification_%']
      );

      settings.forEach((setting: any) => {
        const key = setting.config_key.replace('sms_verification_', '');
        switch (key) {
          case 'enabled':
            this.config.enabled = setting.config_value === 'true';
            break;
          case 'expire_minutes':
            this.config.expireMinutes = parseInt(setting.config_value);
            break;
          case 'resend_interval':
            this.config.resendInterval = parseInt(setting.config_value);
            break;
          case 'max_attempts':
            this.config.maxAttempts = parseInt(setting.config_value);
            break;
        }
      });
    } catch (error) {
      logger.error('加载短信验证配置失败:', error);
    }
  }

  /**
   * 生成随机验证码
   */
  private generateVerificationCode(): string {
    return randomInt(100000, 999999).toString();
  }

  /**
   * 发送短信验证码（模拟实现）
   */
  private async sendSMS(phone: string, code: string, type: string): Promise<boolean> {
    try {
      // 在实际项目中，这里需要集成短信服务商API
      // 例如：阿里云短信、腾讯云短信等
      
      logger.info(`发送短信验证码: ${phone} -> ${code} (${type})`);
      
      // 模拟发送成功
      return true;
    } catch (error) {
      logger.error('发送短信失败:', error);
      return false;
    }
  }

  /**
   * 生成并发送验证码
   */
  async generateAndSendCode(phone: string, type: string): Promise<{ success: boolean; code?: string; message: string }> {
    if (!this.config.enabled) {
      return { success: true, code: '123456', message: '短信验证已禁用，使用默认验证码' };
    }

    try {
      // 检查是否在重发间隔内
      const [recentCodes]: any = await db.execute(
        'SELECT created_at FROM sms_verifications WHERE phone = ? AND verification_type = ? AND created_at > DATE_SUB(NOW(), INTERVAL ? SECOND) ORDER BY created_at DESC LIMIT 1',
        [phone, type, this.config.resendInterval]
      );

      if (recentCodes.length > 0) {
        return { success: false, message: `请等待${this.config.resendInterval}秒后再发送` };
      }

      // 生成验证码
      const code = this.generateVerificationCode();
      const expiresAt = new Date(Date.now() + this.config.expireMinutes * 60 * 1000);

      // 发送短信
      const sendResult = await this.sendSMS(phone, code, type);
      if (!sendResult) {
        return { success: false, message: '短信发送失败，请稍后重试' };
      }

      // 保存验证码记录
      await db.execute(
        'INSERT INTO sms_verifications (phone, verification_code, verification_type, expires_at, used) VALUES (?, ?, ?, ?, 0)',
        [phone, code, type, expiresAt]
      );

      // 清理过期的验证码记录
      await db.execute('DELETE FROM sms_verifications WHERE expires_at < NOW()');

      return { success: true, code, message: '验证码发送成功' };
    } catch (error) {
      logger.error('生成验证码失败:', error);
      return { success: false, message: '系统错误，请稍后重试' };
    }
  }

  /**
   * 验证短信验证码
   */
  async verifyCode(phone: string, code: string, type: string): Promise<{ success: boolean; message: string }> {
    if (!this.config.enabled) {
      // 开发环境默认验证码
      if (code === '123456') {
        return { success: true, message: '验证成功' };
      }
      return { success: false, message: '验证码错误' };
    }

    try {
      // 查找有效的验证码记录
      const [records]: any = await db.execute(
        'SELECT id, verification_code, expires_at, used FROM sms_verifications WHERE phone = ? AND verification_type = ? AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1',
        [phone, type]
      );

      if (records.length === 0) {
        return { success: false, message: '验证码不存在或已过期' };
      }

      const record = records[0];

      if (record.used) {
        return { success: false, message: '验证码已被使用' };
      }

      if (record.verification_code !== code) {
        // 记录验证失败次数
        await this.recordVerificationAttempt(phone, type, false);
        return { success: false, message: '验证码错误' };
      }

      // 标记验证码为已使用
      await db.execute(
        'UPDATE sms_verifications SET used = 1 WHERE id = ?',
        [record.id]
      );

      // 记录验证成功
      await this.recordVerificationAttempt(phone, type, true);

      return { success: true, message: '验证成功' };
    } catch (error) {
      logger.error('验证验证码失败:', error);
      return { success: false, message: '系统错误，请稍后重试' };
    }
  }

  /**
   * 记录验证尝试
   */
  private async recordVerificationAttempt(phone: string, type: string, success: boolean): Promise<void> {
    try {
      // 在实际项目中，可以记录验证尝试日志用于安全分析
      if (!success) {
        logger.warn(`验证码验证失败: ${phone} (${type})`);
      }
    } catch (error) {
      logger.error('记录验证尝试失败:', error);
    }
  }

  /**
   * 检查验证码尝试次数是否超过限制
   */
  async checkAttemptLimit(phone: string, type: string): Promise<{ exceeded: boolean; message?: string }> {
    try {
      const [attempts]: any = await db.execute(
        'SELECT COUNT(*) as count FROM sms_verifications WHERE phone = ? AND verification_type = ? AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR) AND used = 0',
        [phone, type]
      );

      const attemptCount = attempts[0]?.count || 0;

      if (attemptCount >= this.config.maxAttempts) {
        return { exceeded: true, message: '验证码尝试次数过多，请1小时后再试' };
      }

      return { exceeded: false };
    } catch (error) {
      logger.error('检查验证码尝试次数失败:', error);
      return { exceeded: false };
    }
  }
}

export default new SMSVerificationService();