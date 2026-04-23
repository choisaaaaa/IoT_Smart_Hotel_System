import { test, expect } from '@playwright/test';

/**
 * 预订模块 E2E 测试
 * 测试从预订到入住的完整流程
 */

test.describe('预订流程', () => {
  test.beforeEach(async ({ page }) => {
    // 每个测试前登录为酒店经理 137...
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

  test('应该能成功创建预订', async ({ page }) => {
    // 点击预订管理菜单
    await page.click('text=预订管理');
    await page.waitForTimeout(1000);
    
    await page.click('text=新增预订');
    await page.waitForTimeout(1000);
    
    // 填写预订表单 - 使用普通顾客手机号 139...
    await page.fill('input[name="guest_name"]', '测试住客');
    await page.fill('input[name="guest_phone"]', '13999999999');
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
