import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright E2E 测试配置
 * 用于端到端测试慧宿智联系统
 * 
 * 运行方式:
 * 1. 安装依赖: npm install -D @playwright/test
 * 2. 安装浏览器: npx playwright install
 * 3. 运行测试: npx playwright test
 * 4. 查看报告: npx playwright show-report
 */

export default defineConfig({
  testDir: './specs',
  
  // 禁用完全并行模式，防止多个测试同时操作数据库导致冲突
  fullyParallel: false,
  
  // 禁止在 CI 中并行运行测试
  forbidOnly: !!process.env.CI,
  
  // 重试次数
  retries: process.env.CI ? 2 : 0,
  
  // 并行工作进程数：设置为 1 以限制单次任务数，防止互相抢占服务导致卡死
  workers: 1,
  
  // 报告器配置
  reporter: [
    ['html', { open: 'never' }],
    ['json', { outputFile: 'reports/e2e_results.json' }],
    ['list']
  ],
  
  // 共享配置
  use: {
    // 基础 URL
    baseURL: process.env.BASE_URL || 'http://localhost:5173',
    
    // 收集所有跟踪信息
    trace: 'on-first-retry',
    
    // 截图配置
    screenshot: 'only-on-failure',
    
    // 视频录制
    video: 'on-first-retry',
    
    // 视口大小
    viewport: { width: 1280, height: 720 },
    
    // 动作超时：大幅延长至 30 秒，应对系统运行缓慢
    actionTimeout: 30000,
    
    // 导航超时：大幅延长至 60 秒
    navigationTimeout: 60000,

    // 放缓点击速度：每个动作增加 500ms 延迟，防止自动刷新冲突
    launchOptions: {
      slowMo: 500,
    },
  },

  // 全局超时：延长至 5 分钟
  timeout: 300000,

  // 项目配置
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
