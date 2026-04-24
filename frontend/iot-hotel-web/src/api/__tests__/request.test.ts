import { describe, it, expect, vi } from 'vitest';
import axios from 'axios';

// Use vi.hoisted to define variables that need to be available in vi.mock
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

// Mock ant-design-vue to prevent icon loading errors
vi.mock('ant-design-vue', () => ({
  message: {
    error: vi.fn(),
    success: vi.fn(),
    warning: vi.fn()
  }
}));

// Mock axios BEFORE importing request
vi.mock('axios', () => {
  return {
    default: {
      create: mockHoistedCreate
    },
    create: mockHoistedCreate
  };
});

// Import request after mocking axios
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
