import request from './request';
import type { ApiResponse } from '@/types';

export const systemConfigApi = {
  // 获取特定配置 (公开)
  getConfig: (key: string) => 
    request.get<ApiResponse<string>>(`/system-config/${key}`),

  // 获取所有配置 (仅 System)
  getAllConfigs: () => 
    request.get<ApiResponse<Record<string, string>>>('/system-config'),

  // 更新配置 (仅 System)
  updateConfigs: (configs: Record<string, string>) => 
    request.post<ApiResponse<null>>('/system-config', configs)
};
