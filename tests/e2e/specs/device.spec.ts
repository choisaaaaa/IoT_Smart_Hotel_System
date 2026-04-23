import { test, expect } from '@playwright/test';

/**
 * 设备控制 E2E 测试
 * 测试 IoT 设备控制功能
 */

test.describe('设备控制', () => {
  test.beforeEach(async ({ page }) => {
    // 登录为酒店经理 137...
    await page.goto('/guest/booking');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
    
    const loginModal = page.locator('.login-modal');
    if (!await loginModal.isVisible()) {
      await page.click('.login-btn');
    }
    
    await page.waitForTimeout(1000);
    await page.getByPlaceholder('请输入手机号').fill('13777777777');
    await page.waitForTimeout(500);
    await page.getByPlaceholder('请输入密码').fill('password123');
    await page.waitForTimeout(500);
    await page.click('button[type="submit"]');
    await page.waitForURL(/.*hotel-admin.*/, { timeout: 30000 });
  });

  test('应该显示设备列表', async ({ page }) => {
    await page.click('text=设备管理');
    
    // 验证设备列表页面
    await expect(page.locator('.device-list')).toBeVisible();
    
    // 验证设备卡片或表格
    await expect(page.locator('.device-card, .ant-table')).toBeVisible();
  });

  test('应该能成功控制设备', async ({ page }) => {
    // 点击设备管理菜单
    await page.click('text=设备管理');
    await page.waitForTimeout(2000);
    
    // 查找第一个设备的开关按钮并点击
    const switchBtn = page.locator('.ant-switch').first();
    await switchBtn.waitFor({ state: 'visible' });
    await switchBtn.click();
    await page.waitForTimeout(1000);
    
    // 验证成功提示
    await expect(page.locator('.ant-message-success')).toBeVisible({ timeout: 20000 });
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
