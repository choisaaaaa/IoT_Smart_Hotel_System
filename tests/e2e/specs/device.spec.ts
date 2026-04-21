import { test, expect } from '@playwright/test';

/**
 * 设备控制 E2E 测试
 * 测试 IoT 设备控制功能
 */

test.describe('设备控制', () => {
  test.beforeEach(async ({ page }) => {
    // 登录为管理员
    await page.goto('/login');
    await page.fill('input[name="username"]', 'admin');
    await page.fill('input[name="password"]', 'admin123');
    await page.click('button[type="submit"]');
    await page.waitForURL(/.*admin.*/);
  });

  test('应该显示设备列表', async ({ page }) => {
    await page.click('text=设备管理');
    
    // 验证设备列表页面
    await expect(page.locator('.device-list')).toBeVisible();
    
    // 验证设备卡片或表格
    await expect(page.locator('.device-card, .ant-table')).toBeVisible();
  });

  test('应该能够控制设备开关', async ({ page }) => {
    await page.click('text=设备管理');
    
    // 找到第一个可控制的设备
    const toggleSwitch = page.locator('.device-switch').first();
    
    if (await toggleSwitch.isVisible().catch(() => false)) {
      // 记录当前状态
      const isChecked = await toggleSwitch.isChecked();
      
      // 切换状态
      await toggleSwitch.click();
      
      // 等待状态更新
      await page.waitForTimeout(1000);
      
      // 验证状态改变
      const newState = await toggleSwitch.isChecked();
      expect(newState).not.toBe(isChecked);
    }
  });

  test('应该能够切换睡眠模式', async ({ page }) => {
    await page.click('text=设备管理');
    
    // 查找睡眠模式按钮
    const sleepModeButton = page.locator('button:has-text("睡眠模式")');
    
    if (await sleepModeButton.isVisible().catch(() => false)) {
      await sleepModeButton.click();
      
      // 验证确认对话框
      await expect(page.locator('.ant-modal')).toContainText('确认');
      
      // 确认切换
      await page.click('.ant-modal .ant-btn-primary');
      
      // 验证成功提示
      await expect(page.locator('.ant-message-success')).toContainText('模式切换成功');
    }
  });
});
