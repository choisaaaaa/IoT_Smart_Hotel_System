import { test, expect } from '@playwright/test';

/**
 * 认证模块 E2E 测试
 * 测试登录、权限控制等核心功能
 */

test.describe('认证模块', () => {
  test.describe('管理员登录', () => {
    test('应该成功登录并跳转到管理后台', async ({ page }) => {
      // 访问首页
      await page.goto('/guest/booking');
      
      // 等待页面完全加载稳定
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(2000);
      
      // 如果登录弹窗没显示，则点击登录按钮
      const loginModal = page.locator('.login-modal');
      if (!await loginModal.isVisible()) {
        const loginBtn = page.locator('.login-btn');
        await loginBtn.waitFor({ state: 'visible' });
        await loginBtn.click();
      }
      
      // 等待弹窗动画完成
      await page.waitForTimeout(1000);
      
      // 填写登录表单 - 严格使用 136...
      const phoneInput = page.getByPlaceholder('请输入手机号');
      const passwordInput = page.getByPlaceholder('请输入密码');
      
      await phoneInput.waitFor({ state: 'visible' });
      await phoneInput.fill('13666666666');
      await page.waitForTimeout(500);
      
      await passwordInput.waitFor({ state: 'visible' });
      await passwordInput.fill('password123');
      await page.waitForTimeout(500);
      
      // 点击登录按钮
      const submitBtn = page.locator('button[type="submit"]');
      await submitBtn.click();
      
      // 验证跳转成功 (系统管理员跳转到 /system/dashboard)
      await expect(page).toHaveURL(/.*system.*/, { timeout: 30000 });
      
      // 验证页面包含管理后台元素
      await expect(page.locator('text=集团运营总览|管理后台')).toBeVisible();
    });

    test('错误密码应该显示错误提示', async ({ page }) => {
      await page.goto('/guest/booking');
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(2000);
      
      const loginModal = page.locator('.login-modal');
      if (!await loginModal.isVisible()) {
        await page.click('.login-btn');
      }
      
      await page.waitForTimeout(1000);
      await page.getByPlaceholder('请输入手机号').fill('13666666666');
      await page.waitForTimeout(500);
      await page.getByPlaceholder('请输入密码').fill('wrongpassword');
      await page.waitForTimeout(500);
      await page.click('button[type="submit"]');
      
      // 验证错误提示
      await expect(page.locator('.ant-message-error, .error-message')).toContainText(/手机号或密码错误|登录失败/);
    });

    test('空表单应该显示验证错误', async ({ page }) => {
      await page.goto('/guest/booking');
      await page.click('.login-btn');
      
      // 直接点击提交
      await page.click('button[type="submit"]');
      
      // 验证验证错误
      await expect(page.locator('.ant-form-item-explain-error')).toBeVisible();
    });
  });

  test.describe('前台登录', () => {
    test('前台员工应该跳转到前台工作台', async ({ page }) => {
      await page.goto('/guest/booking');
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(2000);
      
      const loginModal = page.locator('.login-modal');
      if (!await loginModal.isVisible()) {
        await page.click('.login-btn');
      }
      
      await page.waitForTimeout(1000);
      await page.getByPlaceholder('请输入手机号').fill('13888888888');
      await page.waitForTimeout(500);
      await page.getByPlaceholder('请输入密码').fill('password123');
      await page.waitForTimeout(500);
      await page.click('button[type="submit"]');
      
      await expect(page).toHaveURL(/.*reception.*/, { timeout: 30000 });
      await expect(page.locator('text=前台工作台|接待中心')).toBeVisible();
    });
  });

  test.describe('权限控制', () => {
    test('未登录用户访问受保护页面应该重定向到登录页', async ({ page }) => {
      await page.goto('/hotel-admin/dashboard');
      
      // 应该重定向到 booking 页并显示登录弹窗
      await expect(page).toHaveURL(/.*guest\/booking.*/, { timeout: 30000 });
      await expect(page.locator('.login-modal')).toBeVisible();
    });

    test('前台员工不应该访问管理员页面', async ({ page }) => {
      // 先登录为前台 138...
      await page.goto('/guest/booking');
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(2000);
      
      const loginModal = page.locator('.login-modal');
      if (!await loginModal.isVisible()) {
        await page.click('.login-btn');
      }
      
      await page.waitForTimeout(1000);
      await page.getByPlaceholder('请输入手机号').fill('13888888888');
      await page.waitForTimeout(500);
      await page.getByPlaceholder('请输入密码').fill('password123');
      await page.waitForTimeout(500);
      await page.click('button[type="submit"]');
      
      await page.waitForURL(/.*reception.*/, { timeout: 30000 });
      
      // 尝试访问管理员页面
      await page.goto('/hotel-admin/rooms/edit');
      
      // 应该显示无权限提示或重定向回前台工作台
      await expect(page.locator('text=无权限|403|Forbidden|前台工作台')).toBeVisible({ timeout: 30000 });
    });
  });
});
