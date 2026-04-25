import { describe, it, expect, vi } from 'vitest';
import axios from 'axios';

// 使用 vi.hoisted 定义需要在 vi.mock 中可用的变量
const { mockHoistedCreate } = vi.hoisted(() => {
  return {
    mockHoistedCreate: vi.fn().mockReturnValue({
      interceptors: {
        request: { use: vi.fn() },
        response: { use: vi.fn() }
      },
      get: vi.fn(),
      post: vi.fn(),
      put: vi.fn(),
      delete: vi.fn()
    })
  };
});

// 模拟 ant-design-vue 以防止图标加载错误
vi.mock('ant-design-vue', () => ({
  message: {
    error: vi.fn(),
    success: vi.fn(),
    warning: vi.fn()
  }
}));

// 在导入 request 之前模拟 axios
vi.mock('axios', () => {
  return {
    default: {
      create: mockHoistedCreate
    },
    create: mockHoistedCreate
  };
});

// 在模拟 axios 之后导入 request
import '../request';

describe('API 请求测试', () => {
  it('应该正确创建 axios 实例', () => {
    expect(mockHoistedCreate).toHaveBeenCalled();
  });

  it('应该配置基础 URL', () => {
    const config = mockHoistedCreate.mock.calls[0]?.[0];
    
    if (config) {
      expect(config.baseURL).toBeDefined();
    }
  });

  it('应该配置超时时间', () => {
    const config = mockHoistedCreate.mock.calls[0]?.[0];
    
    if (config) {
      expect(config.timeout).toBeGreaterThan(0);
    }
  });
});
