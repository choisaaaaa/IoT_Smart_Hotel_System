import request from './request';
import type { ApiResponse } from '@/types';

export const systemConfigApi = {
  // 获取特定配置 (公开)
  getConfig: (key: string) => 
    request.get<any, ApiResponse<string>>(`/system-config/${key}`),

  // 获取所有配置 (仅 System)
  getAllConfigs: () => 
    request.get<any, ApiResponse<Record<string, any>>>('/system-config'),

  // 更新配置 (仅 System)
  updateConfigs: (configs: Record<string, any>) => 
    request.post<any, ApiResponse<null>>('/system-config', configs)
};
