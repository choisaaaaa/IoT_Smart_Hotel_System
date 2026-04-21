import { test, expect } from '@playwright/test';

/**
 * 认证模块 E2E 测试
 * 测试登录、权限控制等核心功能
 */

test.describe('认证模块', () => {
  test.describe('管理员登录', () => {
    test('应该成功登录并跳转到管理后台', async ({ page }) => {
      // 访问登录页
      await page.goto('/login');
      
      // 填写登录表单
      await page.fill('input[name="username"]', 'admin');
      await page.fill('input[name="password"]', 'admin123');
      
      // 点击登录按钮
      await page.click('button[type="submit"]');
      
      // 验证跳转成功
      await expect(page).toHaveURL(/.*admin.*/);
      
      // 验证页面包含管理后台元素
      await expect(page.locator('text=管理后台')).toBeVisible();
    });

    test('错误密码应该显示错误提示', async ({ page }) => {
      await page.goto('/login');
      
      await page.fill('input[name="username"]', 'admin');
      await page.fill('input[name="password"]', 'wrongpassword');
      await page.click('button[type="submit"]');
      
      // 验证错误提示
      await expect(page.locator('.ant-message-error, .error-message')).toContainText(/密码错误|登录失败/);
      
      // 验证仍在登录页
      await expect(page).toHaveURL('/login');
    });

    test('空表单应该显示验证错误', async ({ page }) => {
      await page.goto('/login');
      
      // 直接点击提交
      await page.click('button[type="submit"]');
      
      // 验证验证错误
      await expect(page.locator('.ant-form-item-explain-error')).toBeVisible();
    });
  });

  test.describe('前台登录', () => {
    test('前台员工应该跳转到前台工作台', async ({ page }) => {
      await page.goto('/login');
      
      await page.fill('input[name="username"]', 'receptionist');
      await page.fill('input[name="password"]', 'reception123');
      await page.click('button[type="submit"]');
      
      await expect(page).toHaveURL(/.*reception.*/);
      await expect(page.locator('text=前台工作台')).toBeVisible();
    });
  });

  test.describe('权限控制', () => {
    test('未登录用户访问受保护页面应该重定向到登录页', async ({ page }) => {
      await page.goto('/admin/dashboard');
      
      await expect(page).toHaveURL('/login');
    });

    test('前台员工不应该访问管理员页面', async ({ page }) => {
      // 先登录为前台
      await page.goto('/login');
      await page.fill('input[name="username"]', 'receptionist');
      await page.fill('input[name="password"]', 'reception123');
      await page.click('button[type="submit"]');
      
      // 尝试访问管理员页面
      await page.goto('/admin/users');
      
      // 应该显示无权限提示或重定向
      await expect(page.locator('text=无权限|403|Forbidden')).toBeVisible();
    });
  });
});
