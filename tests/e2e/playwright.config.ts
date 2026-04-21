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
  
  // 完全并行运行测试
  fullyParallel: true,
  
  // 禁止在 CI 中并行运行测试
  forbidOnly: !!process.env.CI,
  
  // 重试次数
  retries: process.env.CI ? 2 : 0,
  
  // 并行工作进程数
  workers: process.env.CI ? 1 : undefined,
  
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
    
    // 动作超时
    actionTimeout: 15000,
    
    // 导航超时
    navigationTimeout: 30000,
  },

  // 项目配置
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    // 移动端测试
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] },
    },
  ],

  // 本地开发服务器配置
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
});
