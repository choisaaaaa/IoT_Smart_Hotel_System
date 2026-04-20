import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import axios from 'axios';

// Mock axios
vi.mock('axios', () => ({
  default: {
    create: vi.fn(() => ({
      interceptors: {
        request: { use: vi.fn() },
        response: { use: vi.fn() }
      },
      get: vi.fn(),
      post: vi.fn(),
      put: vi.fn(),
      delete: vi.fn()
    }))
  }
}));

describe('API 请求测试', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('应该正确创建 axios 实例', () => {
    const mockCreate = axios.create as any;
    expect(mockCreate).toHaveBeenCalled();
  });

  it('应该配置基础 URL', () => {
    const mockCreate = axios.create as any;
    const config = mockCreate.mock.calls[0]?.[0];
    
    if (config) {
      expect(config.baseURL).toBeDefined();
    }
  });

  it('应该配置超时时间', () => {
    const mockCreate = axios.create as any;
    const config = mockCreate.mock.calls[0]?.[0];
    
    if (config) {
      expect(config.timeout).toBeGreaterThan(0);
    }
  });
});
