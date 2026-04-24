# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: auth.spec.ts >> 认证模块 >> 管理员登录 >> 应该成功登录并跳转到管理后台
- Location: specs\auth.spec.ts:10:9

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: locator('text=集团运营总览|管理后台')
Expected: visible
Timeout: 5000ms
Error: element(s) not found

Call log:
  - Expect "toBeVisible" with timeout 5000ms
  - waiting for locator('text=集团运营总览|管理后台')

```

# Page snapshot

```yaml
- generic [ref=e3]:
  - complementary [ref=e4]:
    - generic [ref=e5]:
      - generic [ref=e6] [cursor=pointer]:
        - img "Logo" [ref=e7]
        - generic [ref=e8]: ZhiLianHotel
      - menu [ref=e10]:
        - menuitem "dashboard 系统概览" [ref=e11] [cursor=pointer]:
          - img "dashboard" [ref=e12]:
            - img [ref=e13]
          - generic [ref=e15]: 系统概览
        - menuitem "bank 酒店维护" [ref=e16] [cursor=pointer]:
          - img "bank" [ref=e17]:
            - img [ref=e18]
          - generic [ref=e20]: 酒店维护
        - menuitem "mobile 全局设备" [ref=e21] [cursor=pointer]:
          - img "mobile" [ref=e22]:
            - img [ref=e23]
          - generic [ref=e25]: 全局设备
        - menuitem "user 账户管理" [ref=e26] [cursor=pointer]:
          - img "user" [ref=e27]:
            - img [ref=e28]
          - generic [ref=e30]: 账户管理
        - menuitem "gift 优惠券管理" [ref=e31] [cursor=pointer]:
          - img "gift" [ref=e32]:
            - img [ref=e33]
          - generic [ref=e35]: 优惠券管理
        - menuitem "setting 系统配置" [ref=e36] [cursor=pointer]:
          - img "setting" [ref=e37]:
            - img [ref=e38]
          - generic [ref=e40]: 系统配置
  - generic [ref=e41]:
    - generic [ref=e42]:
      - generic [ref=e43]:
        - img "menu-fold" [ref=e44] [cursor=pointer]:
          - img [ref=e45]
        - navigation [ref=e47]:
          - list [ref=e48]:
            - listitem [ref=e49]:
              - generic [ref=e50]: 集团运营总览
      - generic [ref=e52] [cursor=pointer]:
        - img "user" [ref=e54]:
          - img [ref=e55]
        - generic [ref=e57]: 测试系统管理员
    - main [ref=e58]:
      - generic [ref=e59]:
        - generic [ref=e60]:
          - generic [ref=e61]:
            - heading "集团运营总览" [level=1] [ref=e62]
            - paragraph [ref=e63]: 欢迎回来，测试系统管理员。这是智联酒店集团的全局实时运营概报。
          - button "reload 刷新数据" [ref=e66] [cursor=pointer]:
            - img "reload" [ref=e67]:
              - img [ref=e68]
            - generic [ref=e70]: 刷新数据
        - generic [ref=e71]:
          - generic [ref=e75]:
            - generic [ref=e76]: 运营酒店
            - generic [ref=e77]:
              - img "bank" [ref=e79]:
                - img [ref=e80]
              - generic [ref=e83]: "6"
              - generic [ref=e84]: 家
          - generic [ref=e88]:
            - generic [ref=e89]: 集团总会员
            - generic [ref=e90]:
              - img "team" [ref=e92]:
                - img [ref=e93]
              - generic [ref=e96]: "29"
              - generic [ref=e97]: 位
          - generic [ref=e101]:
            - generic [ref=e102]: 联网设备总数
            - generic [ref=e103]:
              - img "desktop" [ref=e105]:
                - img [ref=e106]
              - generic [ref=e109]: "21"
          - generic [ref=e113]:
            - generic [ref=e114]: 集团总营收 (本月)
            - generic [ref=e115]:
              - img "dollar" [ref=e117]:
                - img [ref=e118]
              - generic [ref=e120]:
                - generic [ref=e121]: 54,115
                - text: ".01"
        - generic [ref=e122]:
          - generic [ref=e127]: 集团营收趋势 (月度)
          - generic [ref=e133]:
            - generic [ref=e136]: 酒店营收排行 (TOP 5)
            - list [ref=e141]:
              - listitem [ref=e142]:
                - generic [ref=e143]:
                  - generic [ref=e144]: "1"
                  - generic [ref=e145]: ZhiLianHotel
                  - generic [ref=e146]: ¥33,887.41
              - listitem [ref=e147]:
                - generic [ref=e148]:
                  - generic [ref=e149]: "2"
                  - generic [ref=e150]: 无畏电竞酒店
                  - generic [ref=e151]: ¥17,754.16
              - listitem [ref=e152]:
                - generic [ref=e153]:
                  - generic [ref=e154]: "3"
                  - generic [ref=e155]: 刘烨黄金酒店
                  - generic [ref=e156]: ¥4,881.34
              - listitem [ref=e157]:
                - generic [ref=e158]:
                  - generic [ref=e159]: "4"
                  - generic [ref=e160]: 公开测试酒店
                  - generic [ref=e161]: ¥807.3
              - listitem [ref=e162]:
                - generic [ref=e163]:
                  - generic [ref=e164]: "5"
                  - generic [ref=e165]: APITestHotel
                  - generic [ref=e166]: ¥0
        - generic [ref=e167]:
          - generic [ref=e172]: 全集团房态分布
          - generic [ref=e181]: 今日预订概况
```

# Test source

```ts
  1   | import { test, expect } from '@playwright/test';
  2   | 
  3   | /**
  4   |  * 认证模块 E2E 测试
  5   |  * 测试登录、权限控制等核心功能
  6   |  */
  7   | 
  8   | test.describe('认证模块', () => {
  9   |   test.describe('管理员登录', () => {
  10  |     test('应该成功登录并跳转到管理后台', async ({ page }) => {
  11  |       // 访问首页
  12  |       await page.goto('/guest/booking');
  13  |       
  14  |       // 等待页面完全加载稳定
  15  |       await page.waitForLoadState('networkidle');
  16  |       await page.waitForTimeout(2000);
  17  |       
  18  |       // 如果登录弹窗没显示，则点击登录按钮
  19  |       const loginModal = page.locator('.login-modal');
  20  |       if (!await loginModal.isVisible()) {
  21  |         const loginBtn = page.locator('.login-btn');
  22  |         await loginBtn.waitFor({ state: 'visible' });
  23  |         await loginBtn.click();
  24  |       }
  25  |       
  26  |       // 等待弹窗动画完成
  27  |       await page.waitForTimeout(1000);
  28  |       
  29  |       // 填写登录表单 - 严格使用 136...
  30  |       const phoneInput = page.getByPlaceholder('请输入手机号');
  31  |       const passwordInput = page.getByPlaceholder('请输入密码');
  32  |       
  33  |       await phoneInput.waitFor({ state: 'visible' });
  34  |       await phoneInput.fill('13666666666');
  35  |       await page.waitForTimeout(500);
  36  |       
  37  |       await passwordInput.waitFor({ state: 'visible' });
  38  |       await passwordInput.fill('password123');
  39  |       await page.waitForTimeout(500);
  40  |       
  41  |       // 点击登录按钮
  42  |       const submitBtn = page.locator('button[type="submit"]');
  43  |       await submitBtn.click();
  44  |       
  45  |       // 验证跳转成功 (系统管理员跳转到 /system/dashboard)
  46  |       await expect(page).toHaveURL(/.*system.*/, { timeout: 30000 });
  47  |       
  48  |       // 验证页面包含管理后台元素
> 49  |       await expect(page.locator('text=集团运营总览|管理后台')).toBeVisible();
      |                                                      ^ Error: expect(locator).toBeVisible() failed
  50  |     });
  51  | 
  52  |     test('错误密码应该显示错误提示', async ({ page }) => {
  53  |       await page.goto('/guest/booking');
  54  |       await page.waitForLoadState('networkidle');
  55  |       await page.waitForTimeout(2000);
  56  |       
  57  |       const loginModal = page.locator('.login-modal');
  58  |       if (!await loginModal.isVisible()) {
  59  |         await page.click('.login-btn');
  60  |       }
  61  |       
  62  |       await page.waitForTimeout(1000);
  63  |       await page.getByPlaceholder('请输入手机号').fill('13666666666');
  64  |       await page.waitForTimeout(500);
  65  |       await page.getByPlaceholder('请输入密码').fill('wrongpassword');
  66  |       await page.waitForTimeout(500);
  67  |       await page.click('button[type="submit"]');
  68  |       
  69  |       // 验证错误提示
  70  |       await expect(page.locator('.ant-message-error, .error-message')).toContainText(/手机号或密码错误|登录失败/);
  71  |     });
  72  | 
  73  |     test('空表单应该显示验证错误', async ({ page }) => {
  74  |       await page.goto('/guest/booking');
  75  |       await page.click('.login-btn');
  76  |       
  77  |       // 直接点击提交
  78  |       await page.click('button[type="submit"]');
  79  |       
  80  |       // 验证验证错误
  81  |       await expect(page.locator('.ant-form-item-explain-error')).toBeVisible();
  82  |     });
  83  |   });
  84  | 
  85  |   test.describe('前台登录', () => {
  86  |     test('前台员工应该跳转到前台工作台', async ({ page }) => {
  87  |       await page.goto('/guest/booking');
  88  |       await page.waitForLoadState('networkidle');
  89  |       await page.waitForTimeout(2000);
  90  |       
  91  |       const loginModal = page.locator('.login-modal');
  92  |       if (!await loginModal.isVisible()) {
  93  |         await page.click('.login-btn');
  94  |       }
  95  |       
  96  |       await page.waitForTimeout(1000);
  97  |       await page.getByPlaceholder('请输入手机号').fill('13888888888');
  98  |       await page.waitForTimeout(500);
  99  |       await page.getByPlaceholder('请输入密码').fill('password123');
  100 |       await page.waitForTimeout(500);
  101 |       await page.click('button[type="submit"]');
  102 |       
  103 |       await expect(page).toHaveURL(/.*reception.*/, { timeout: 30000 });
  104 |       await expect(page.locator('text=前台工作台|接待中心')).toBeVisible();
  105 |     });
  106 |   });
  107 | 
  108 |   test.describe('权限控制', () => {
  109 |     test('未登录用户访问受保护页面应该重定向到登录页', async ({ page }) => {
  110 |       await page.goto('/hotel-admin/dashboard');
  111 |       
  112 |       // 应该重定向到 booking 页并显示登录弹窗
  113 |       await expect(page).toHaveURL(/.*guest\/booking.*/, { timeout: 30000 });
  114 |       await expect(page.locator('.login-modal')).toBeVisible();
  115 |     });
  116 | 
  117 |     test('前台员工不应该访问管理员页面', async ({ page }) => {
  118 |       // 先登录为前台 138...
  119 |       await page.goto('/guest/booking');
  120 |       await page.waitForLoadState('networkidle');
  121 |       await page.waitForTimeout(2000);
  122 |       
  123 |       const loginModal = page.locator('.login-modal');
  124 |       if (!await loginModal.isVisible()) {
  125 |         await page.click('.login-btn');
  126 |       }
  127 |       
  128 |       await page.waitForTimeout(1000);
  129 |       await page.getByPlaceholder('请输入手机号').fill('13888888888');
  130 |       await page.waitForTimeout(500);
  131 |       await page.getByPlaceholder('请输入密码').fill('password123');
  132 |       await page.waitForTimeout(500);
  133 |       await page.click('button[type="submit"]');
  134 |       
  135 |       await page.waitForURL(/.*reception.*/, { timeout: 30000 });
  136 |       
  137 |       // 尝试访问管理员页面
  138 |       await page.goto('/hotel-admin/rooms/edit');
  139 |       
  140 |       // 应该显示无权限提示或重定向回前台工作台
  141 |       await expect(page.locator('text=无权限|403|Forbidden|前台工作台')).toBeVisible({ timeout: 30000 });
  142 |     });
  143 |   });
  144 | });
  145 | 
```