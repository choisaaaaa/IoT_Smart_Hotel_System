# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: auth.spec.ts >> 认证模块 >> 管理员登录 >> 空表单应该显示验证错误
- Location: specs\auth.spec.ts:73:9

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: locator('.ant-form-item-explain-error')
Expected: visible
Error: strict mode violation: locator('.ant-form-item-explain-error') resolved to 2 elements:
    1) <div class="ant-form-item-explain-error">请输入手机号</div> aka getByText('请输入手机号')
    2) <div class="ant-form-item-explain-error">请输入密码</div> aka getByText('请输入密码')

Call log:
  - Expect "toBeVisible" with timeout 5000ms
  - waiting for locator('.ant-form-item-explain-error')

```

# Page snapshot

```yaml
- generic [ref=e1]:
  - generic [ref=e4]:
    - generic [ref=e5]:
      - generic [ref=e7] [cursor=pointer]:
        - img "Logo" [ref=e9]
        - generic [ref=e11]: ZhiLianHotel
      - generic [ref=e12]:
        - button "compass 探索旅程" [ref=e13] [cursor=pointer]:
          - img "compass" [ref=e14]:
            - img [ref=e15]
          - generic [ref=e17]: 探索旅程
        - button "idcard 预入住" [ref=e18] [cursor=pointer]:
          - img "idcard" [ref=e19]:
            - img [ref=e20]
          - generic [ref=e22]: 预入住
        - button "file-text 我的订单" [ref=e23] [cursor=pointer]:
          - img "file-text" [ref=e24]:
            - img [ref=e25]
          - generic [ref=e27]: 我的订单
        - button "user 个人中心" [ref=e28] [cursor=pointer]:
          - img "user" [ref=e29]:
            - img [ref=e30]
          - generic [ref=e32]: 个人中心
      - generic [ref=e33]:
        - generic [ref=e36]: 连接中
        - button "user 登录 / 注册" [ref=e37] [cursor=pointer]:
          - img "user" [ref=e38]:
            - img [ref=e39]
          - generic [ref=e41]: 登录 / 注册
    - main [ref=e42]:
      - generic [ref=e43]:
        - generic [ref=e44]:
          - generic [ref=e46]:
            - heading "探索您的完美下榻之地" [level=1] [ref=e47]
            - paragraph [ref=e48]: 100,000+ 间智能客房 · 实时预订 · 极速入住
          - generic [ref=e53]:
            - generic [ref=e55]:
              - generic [ref=e56]: 目的地/酒店名称
              - generic [ref=e57]:
                - img "environment" [ref=e59]:
                  - img [ref=e60]
                - textbox "城市、商圈或酒店" [ref=e62]
            - generic [ref=e64]:
              - generic [ref=e65]: 入住 - 退房日期
              - generic [ref=e66]:
                - textbox "开始日期" [ref=e68]: 2026-04-24
                - generic [ref=e69]: "-"
                - textbox "结束日期" [ref=e71]: 2026-04-25
                - generic:
                  - img "calendar":
                    - img
                - img "close-circle" [ref=e73] [cursor=pointer]:
                  - img [ref=e74]
            - generic [ref=e77]:
              - generic [ref=e78]: 房间及人数
              - generic [ref=e79] [cursor=pointer]:
                - img "user" [ref=e80]:
                  - img [ref=e81]
                - generic [ref=e83]: 1间, 2人
            - button "搜 索" [ref=e85] [cursor=pointer]:
              - generic [ref=e86]: 搜 索
        - generic [ref=e88]:
          - heading "🏨 合作智能酒店" [level=2] [ref=e90]
          - generic [ref=e91]:
            - generic [ref=e93] [cursor=pointer]:
              - img "ZhiLianHotel" [ref=e95]
              - generic [ref=e96]:
                - generic [ref=e97]:
                  - heading "ZhiLianHotel" [level=3] [ref=e98]
                  - generic [ref=e99]:
                    - img "star" [ref=e100]:
                      - img [ref=e101]
                    - img "star" [ref=e103]:
                      - img [ref=e104]
                    - img "star" [ref=e106]:
                      - img [ref=e107]
                    - img "star" [ref=e109]:
                      - img [ref=e110]
                    - img "star" [ref=e112]:
                      - img [ref=e113]
                - generic [ref=e116]:
                  - img "environment" [ref=e117]:
                    - img [ref=e118]
                  - text: Beijing
                - generic [ref=e120]:
                  - generic [ref=e121]: "5.00"
                  - generic [ref=e122]: 超赞 · 1 条评价
                - generic [ref=e123]:
                  - generic [ref=e124]: 免费取消
                  - generic [ref=e125]: 立即确认
                - generic [ref=e127]: ¥299.00/晚起
            - generic [ref=e129] [cursor=pointer]:
              - img "刘烨黄金酒店" [ref=e131]
              - generic [ref=e132]:
                - generic [ref=e133]:
                  - heading "刘烨黄金酒店" [level=3] [ref=e134]
                  - generic [ref=e135]:
                    - img "star" [ref=e136]:
                      - img [ref=e137]
                    - img "star" [ref=e139]:
                      - img [ref=e140]
                    - img "star" [ref=e142]:
                      - img [ref=e143]
                - generic [ref=e146]:
                  - img "environment" [ref=e147]:
                    - img [ref=e148]
                  - text: 酒店地址
                - generic [ref=e150]:
                  - generic [ref=e151]: "5.00"
                  - generic [ref=e152]: 超赞 · 1 条评价
                - generic [ref=e153]:
                  - generic [ref=e154]: 免费取消
                  - generic [ref=e155]: 立即确认
                - generic [ref=e157]: ¥269.00/晚起
            - generic [ref=e159] [cursor=pointer]:
              - img "公开测试酒店" [ref=e161]
              - generic [ref=e162]:
                - generic [ref=e163]:
                  - heading "公开测试酒店" [level=3] [ref=e164]
                  - generic [ref=e165]:
                    - img "star" [ref=e166]:
                      - img [ref=e167]
                    - img "star" [ref=e169]:
                      - img [ref=e170]
                    - img "star" [ref=e172]:
                      - img [ref=e173]
                    - img "star" [ref=e175]:
                      - img [ref=e176]
                    - img "star" [ref=e178]:
                      - img [ref=e179]
                - generic [ref=e182]:
                  - img "environment" [ref=e183]:
                    - img [ref=e184]
                  - text: 酒店地址
                - generic [ref=e186]:
                  - generic [ref=e187]: "4.50"
                  - generic [ref=e188]: 超赞 · 100 条评价
                - generic [ref=e189]:
                  - generic [ref=e190]: 免费取消
                  - generic [ref=e191]: 立即确认
                - generic [ref=e193]: ¥279.00/晚起
            - generic [ref=e195] [cursor=pointer]:
              - img "无畏电竞酒店" [ref=e197]
              - generic [ref=e198]:
                - generic [ref=e199]:
                  - heading "无畏电竞酒店" [level=3] [ref=e200]
                  - generic [ref=e201]:
                    - img "star" [ref=e202]:
                      - img [ref=e203]
                    - img "star" [ref=e205]:
                      - img [ref=e206]
                    - img "star" [ref=e208]:
                      - img [ref=e209]
                    - img "star" [ref=e211]:
                      - img [ref=e212]
                    - img "star" [ref=e214]:
                      - img [ref=e215]
                - generic [ref=e218]:
                  - img "environment" [ref=e219]:
                    - img [ref=e220]
                  - text: 中澳友谊花园
                - generic [ref=e222]:
                  - generic [ref=e223]: "4.70"
                  - generic [ref=e224]: 超赞 · 2 条评价
                - generic [ref=e225]:
                  - generic [ref=e226]: 免费取消
                  - generic [ref=e227]: 立即确认
                - generic [ref=e229]: ¥399.00/晚起
            - generic [ref=e231] [cursor=pointer]:
              - generic [ref=e232]:
                - img "test" [ref=e233]
                - generic [ref=e234]: 已售罄
              - generic [ref=e235]:
                - generic [ref=e236]:
                  - heading "test" [level=3] [ref=e237]
                  - generic [ref=e238]:
                    - img "star" [ref=e239]:
                      - img [ref=e240]
                    - img "star" [ref=e242]:
                      - img [ref=e243]
                    - img "star" [ref=e245]:
                      - img [ref=e246]
                - generic [ref=e249]:
                  - img "environment" [ref=e250]:
                    - img [ref=e251]
                  - text: 酒店地址
                - generic [ref=e253]:
                  - generic [ref=e254]: "4.50"
                  - generic [ref=e255]: 超赞 · 100 条评价
                - generic [ref=e256]:
                  - generic [ref=e257]: 免费取消
                  - generic [ref=e258]: 立即确认
                - generic [ref=e260]: ¥300.00/晚起
            - generic [ref=e262] [cursor=pointer]:
              - generic [ref=e263]:
                - img "APITestHotel" [ref=e264]
                - generic [ref=e265]: 已售罄
              - generic [ref=e266]:
                - generic [ref=e267]:
                  - heading "APITestHotel" [level=3] [ref=e268]
                  - generic [ref=e269]:
                    - img "star" [ref=e270]:
                      - img [ref=e271]
                    - img "star" [ref=e273]:
                      - img [ref=e274]
                    - img "star" [ref=e276]:
                      - img [ref=e277]
                - generic [ref=e280]:
                  - img "environment" [ref=e281]:
                    - img [ref=e282]
                  - text: TestAddress
                - generic [ref=e284]:
                  - generic [ref=e285]: "4.50"
                  - generic [ref=e286]: 超赞 · 100 条评价
                - generic [ref=e287]:
                  - generic [ref=e288]: 免费取消
                  - generic [ref=e289]: 立即确认
                - generic [ref=e291]: ¥300.00/晚起
    - generic [ref=e293]:
      - generic [ref=e294]:
        - img "home" [ref=e295]:
          - img [ref=e296]
        - generic [ref=e298]: 慧宿智联
      - generic [ref=e299]:
        - link "关于我们" [ref=e300] [cursor=pointer]:
          - /url: "#"
        - link "服务条款" [ref=e301] [cursor=pointer]:
          - /url: "#"
        - link "隐私政策" [ref=e302] [cursor=pointer]:
          - /url: "#"
        - link "联系客服" [ref=e303] [cursor=pointer]:
          - /url: "#"
      - generic [ref=e304]:
        - paragraph [ref=e305]: 2026 慧宿智联 · 云边端一体化智能酒店物联网解决方案
        - paragraph [ref=e306]: 让每一次入住都成为美好回忆
  - dialog [ref=e308]:
    - document:
      - generic [ref=e309]:
        - button "Close" [ref=e310] [cursor=pointer]:
          - img "close" [ref=e312]:
            - img [ref=e313]
        - generic [ref=e315]:
          - generic [ref=e316]:
            - img "home" [ref=e318]:
              - img [ref=e319]
            - heading "欢迎回到慧宿智联" [level=3] [ref=e321]
            - paragraph [ref=e322]: 开启您的智慧酒店之旅
          - generic [ref=e323]:
            - tablist [ref=e324]:
              - generic [ref=e326]:
                - tab "密码登录" [selected] [ref=e328] [cursor=pointer]
                - tab "扫码登录" [ref=e330] [cursor=pointer]
            - tabpanel "密码登录" [ref=e333]:
              - generic [ref=e334]:
                - generic [ref=e336]:
                  - generic "手机号码" [ref=e338]: "* 手机号码"
                  - generic [ref=e339]:
                    - generic [ref=e342]:
                      - img "mobile" [ref=e344]:
                        - img [ref=e345]
                      - textbox "* 手机号码" [ref=e347]:
                        - /placeholder: 请输入手机号
                    - alert [ref=e349]:
                      - generic [ref=e350]: 请输入手机号
                - generic [ref=e352]:
                  - generic "登录密码" [ref=e354]: "* 登录密码"
                  - generic [ref=e355]:
                    - generic [ref=e358]:
                      - img "lock" [ref=e360]:
                        - img [ref=e361]
                      - textbox "* 登录密码" [ref=e363]:
                        - /placeholder: 请输入密码
                      - img "eye-invisible" [ref=e365] [cursor=pointer]:
                        - img [ref=e366]
                    - alert [ref=e370]:
                      - generic [ref=e371]: 请输入密码
                - button "登 录" [active] [ref=e377] [cursor=pointer]:
                  - generic [ref=e378]: 登 录
                - generic [ref=e379]: 还没有账号？立即注册
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
  49  |       await expect(page.locator('text=集团运营总览|管理后台')).toBeVisible();
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
> 81  |       await expect(page.locator('.ant-form-item-explain-error')).toBeVisible();
      |                                                                  ^ Error: expect(locator).toBeVisible() failed
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