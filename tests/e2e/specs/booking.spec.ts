import { test, expect } from '@playwright/test';

/**
 * 预订模块 E2E 测试
 * 测试从预订到入住的完整流程
 */

test.describe('预订流程', () => {
  test.beforeEach(async ({ page }) => {
    // 每个测试前登录为管理员
    await page.goto('/login');
    await page.fill('input[name="username"]', 'admin');
    await page.fill('input[name="password"]', 'admin123');
    await page.click('button[type="submit"]');
    await page.waitForURL(/.*admin.*/);
  });

  test('应该能够创建新预订', async ({ page }) => {
    // 导航到预订管理
    await page.click('text=预订管理');
    await page.click('text=新建预订');
    
    // 填写预订表单
    await page.fill('input[name="guest_name"]', '测试住客');
    await page.fill('input[name="guest_phone"]', '13800138000');
    await page.fill('input[name="check_in_date"]', '2026-05-01');
    await page.fill('input[name="check_out_date"]', '2026-05-03');
    
    // 选择房型
    await page.click('.room-type-selector');
    await page.click('.ant-select-item:has-text("标准间")');
    
    // 提交表单
    await page.click('button:has-text("确认预订")');
    
    // 验证成功提示
    await expect(page.locator('.ant-message-success')).toContainText('预订成功');
  });

  test('应该能够查询预订列表', async ({ page }) => {
    await page.click('text=预订管理');
    
    // 验证预订列表加载
    await expect(page.locator('.booking-list')).toBeVisible();
    
    // 验证表格有数据
    const rows = page.locator('.ant-table-row');
    await expect(rows.first()).toBeVisible();
  });

  test('应该能够办理入住', async ({ page }) => {
    await page.click('text=预订管理');
    
    // 找到第一个待入住的预订
    const checkInButton = page.locator('button:has-text("办理入住")').first();
    
    if (await checkInButton.isVisible().catch(() => false)) {
      await checkInButton.click();
      
      // 确认入住
      await page.click('button:has-text("确认")');
      
      // 验证成功
      await expect(page.locator('.ant-message-success')).toContainText('入住成功');
    }
  });
});
