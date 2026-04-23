# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: auth.spec.ts >> 认证模块 >> 前台登录 >> 前台员工应该跳转到前台工作台
- Location: specs\auth.spec.ts:86:9

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: locator('text=前台工作台|接待中心')
Expected: visible
Timeout: 5000ms
Error: element(s) not found

Call log:
  - Expect "toBeVisible" with timeout 5000ms
  - waiting for locator('text=前台工作台|接待中心')

```

# Page snapshot

```yaml
- generic [ref=e3]:
  - complementary [ref=e4]:
    - generic [ref=e5]:
      - generic [ref=e6] [cursor=pointer]:
        - img "Logo" [ref=e8]
        - generic [ref=e9]:
          - generic [ref=e10]: 前台工作台
          - generic [ref=e11]: ZhiLianHotel
      - menu [ref=e13]:
        - menuitem "dashboard 前台总览" [ref=e14] [cursor=pointer]:
          - img "dashboard" [ref=e15]:
            - img [ref=e16]
          - generic [ref=e18]: 前台总览
        - menuitem "bell 接待中心" [ref=e19] [cursor=pointer]:
          - img "bell" [ref=e21]:
            - img [ref=e22]
          - generic [ref=e24]: 接待中心
        - menuitem "control 设备管理" [ref=e25] [cursor=pointer]:
          - img "control" [ref=e26]:
            - img [ref=e27]
          - generic [ref=e29]: 设备管理
        - menuitem "calendar 预订管理" [ref=e30] [cursor=pointer]:
          - img "calendar" [ref=e32]:
            - img [ref=e33]
          - generic [ref=e35]: 预订管理
        - menuitem "apartment 客房余量" [ref=e36] [cursor=pointer]:
          - img "apartment" [ref=e37]:
            - img [ref=e38]
          - generic [ref=e40]: 客房余量
        - menuitem "tool 工单处理" [ref=e41] [cursor=pointer]:
          - img "tool" [ref=e43]:
            - img [ref=e44]
          - generic [ref=e46]: 工单处理
        - menuitem "send 客房送物" [ref=e47] [cursor=pointer]:
          - img "send" [ref=e49]:
            - img [ref=e50]
          - generic [ref=e52]: 客房送物
        - menuitem "phone 语音通话" [ref=e53] [cursor=pointer]:
          - img "phone" [ref=e55]:
            - img [ref=e56]
          - generic [ref=e58]: 语音通话
        - menuitem "environment 环境监测" [ref=e59] [cursor=pointer]:
          - img "environment" [ref=e61]:
            - img [ref=e62]
          - generic [ref=e64]: 环境监测
        - menuitem "dollar 价格日历" [ref=e65] [cursor=pointer]:
          - img "dollar" [ref=e66]:
            - img [ref=e67]
          - generic [ref=e69]: 价格日历
        - menuitem "tag 优惠券" [ref=e70] [cursor=pointer]:
          - img "tag" [ref=e71]:
            - img [ref=e72]
          - generic [ref=e74]: 优惠券
        - menuitem "file-text 账单报表" [ref=e75] [cursor=pointer]:
          - img "file-text" [ref=e76]:
            - img [ref=e77]
          - generic [ref=e79]: 账单报表
        - menuitem "safety 特权卡发放" [ref=e80] [cursor=pointer]:
          - img "safety" [ref=e81]:
            - img [ref=e82]
          - generic [ref=e85]: 特权卡发放
  - generic [ref=e86]:
    - generic [ref=e87]:
      - generic [ref=e88]:
        - img "menu-fold" [ref=e89] [cursor=pointer]:
          - img [ref=e90]
        - navigation [ref=e92]:
          - list [ref=e93]:
            - listitem [ref=e94]:
              - generic [ref=e95]: 前台总览
      - generic [ref=e96]:
        - img "bell" [ref=e99] [cursor=pointer]:
          - img [ref=e100]
        - generic [ref=e102]:
          - img "wifi" [ref=e103]:
            - img [ref=e104]
          - generic [ref=e106]: 在线
        - generic [ref=e107] [cursor=pointer]:
          - img "user" [ref=e109]:
            - img [ref=e110]
          - generic [ref=e112]:
            - generic [ref=e113]: 测试门店前台
            - generic [ref=e114]: 前台接待
          - img "down" [ref=e115]:
            - img [ref=e116]
    - main [ref=e118]:
      - generic [ref=e119]:
        - generic [ref=e120]:
          - generic [ref=e121]:
            - img "dashboard" [ref=e122]:
              - img [ref=e123]
            - heading "前台总览" [level=1] [ref=e125]
          - generic [ref=e126]:
            - img "calendar" [ref=e127]:
              - img [ref=e128]
            - generic [ref=e130]: 2026年04月24日 Friday
        - generic [ref=e131]:
          - generic [ref=e133]:
            - img "login" [ref=e135]:
              - img [ref=e136]
            - generic [ref=e138]:
              - generic [ref=e139]: 今日入住
              - generic [ref=e140]: "1"
          - generic [ref=e142]:
            - img "logout" [ref=e144]:
              - img [ref=e145]
            - generic [ref=e147]:
              - generic [ref=e148]: 今日退房
              - generic [ref=e149]: "1"
          - generic [ref=e151]:
            - img "home" [ref=e153]:
              - img [ref=e154]
            - generic [ref=e156]:
              - generic [ref=e157]: 当前入住
              - generic [ref=e158]: "0"
          - generic [ref=e160]:
            - img "pie-chart" [ref=e162]:
              - img [ref=e163]
            - generic [ref=e165]:
              - generic [ref=e166]: 入住率
              - generic [ref=e167]: 0%
        - generic [ref=e168]:
          - generic [ref=e169]:
            - img "thunderbolt" [ref=e170]:
              - img [ref=e171]
            - generic [ref=e173]: 快捷操作
          - generic [ref=e174]:
            - generic [ref=e175] [cursor=pointer]:
              - img "calendar" [ref=e178]:
                - img [ref=e179]
              - generic [ref=e181]: 预订管理
              - generic [ref=e182]: 查看和处理预订
            - generic [ref=e183] [cursor=pointer]:
              - img "idcard" [ref=e186]:
                - img [ref=e187]
              - generic [ref=e189]: 接待中心
              - generic [ref=e190]: 办理入住与退房
            - generic [ref=e191] [cursor=pointer]:
              - img "tool" [ref=e194]:
                - img [ref=e195]
              - generic [ref=e197]: 工单处理
              - generic [ref=e198]: 维修与打扫任务
            - generic [ref=e199] [cursor=pointer]:
              - img "send" [ref=e202]:
                - img [ref=e203]
              - generic [ref=e205]: 送物服务
              - generic [ref=e206]: 处理客房送物请求
        - generic [ref=e207]:
          - generic [ref=e209]:
            - generic [ref=e210]:
              - generic [ref=e211]:
                - img "tool" [ref=e212]:
                  - img [ref=e213]
                - generic [ref=e215]: 待处理工单
              - button "查看全部 right" [ref=e216] [cursor=pointer]:
                - generic [ref=e217]: 查看全部
                - img "right" [ref=e218]:
                  - img [ref=e219]
            - generic [ref=e222]:
              - img "check-circle" [ref=e223]:
                - img [ref=e224]
              - paragraph [ref=e227]: 暂无待处理工单
          - generic [ref=e229]:
            - generic [ref=e230]:
              - generic [ref=e231]:
                - img "send" [ref=e232]:
                  - img [ref=e233]
                - generic [ref=e235]: 待配送订单
              - button "查看全部 right" [ref=e236] [cursor=pointer]:
                - generic [ref=e237]: 查看全部
                - img "right" [ref=e238]:
                  - img [ref=e239]
            - generic [ref=e242]:
              - img "check-circle" [ref=e243]:
                - img [ref=e244]
              - paragraph [ref=e247]: 暂无待配送订单
        - generic [ref=e248]:
          - generic [ref=e249]:
            - img "calendar" [ref=e250]:
              - img [ref=e251]
            - generic [ref=e253]: 今日预订
          - generic [ref=e256]:
            - table [ref=e260]:
              - rowgroup [ref=e269]:
                - row "预订号 客人姓名 房间号 入住日期 退房日期 状态 操作" [ref=e270]:
                  - columnheader "预订号" [ref=e271]
                  - columnheader "客人姓名" [ref=e272]
                  - columnheader "房间号" [ref=e273]
                  - columnheader "入住日期" [ref=e274]
                  - columnheader "退房日期" [ref=e275]
                  - columnheader "状态" [ref=e276]
                  - columnheader "操作" [ref=e277]
              - rowgroup [ref=e278]:
                - row "xingxing 已确认 办理入住" [ref=e279]:
                  - cell [ref=e280]
                  - cell "xingxing" [ref=e281]
                  - cell [ref=e282]
                  - cell [ref=e283]
                  - cell [ref=e284]
                  - cell "已确认" [ref=e285]:
                    - generic [ref=e286]: 已确认
                  - cell "办理入住" [ref=e287]:
                    - button "办理入住" [ref=e288] [cursor=pointer]:
                      - generic [ref=e289]: 办理入住
                - row "xingxing 已取消 -" [ref=e290]:
                  - cell [ref=e291]
                  - cell "xingxing" [ref=e292]
                  - cell [ref=e293]
                  - cell [ref=e294]
                  - cell [ref=e295]
                  - cell "已取消" [ref=e296]:
                    - generic [ref=e297]: 已取消
                  - cell "-" [ref=e298]
                - row "xingxing2 已取消 -" [ref=e299]:
                  - cell [ref=e300]
                  - cell "xingxing2" [ref=e301]
                  - cell [ref=e302]
                  - cell [ref=e303]
                  - cell [ref=e304]
                  - cell "已取消" [ref=e305]:
                    - generic [ref=e306]: 已取消
                  - cell "-" [ref=e307]
                - 'row "xingxing` 已取消 -" [ref=e308]':
                  - cell [ref=e309]
                  - 'cell "xingxing`" [ref=e310]'
                  - cell [ref=e311]
                  - cell [ref=e312]
                  - cell [ref=e313]
                  - cell "已取消" [ref=e314]:
                    - generic [ref=e315]: 已取消
                  - cell "-" [ref=e316]
                - row "xingxing1 已取消 -" [ref=e317]:
                  - cell [ref=e318]
                  - cell "xingxing1" [ref=e319]
                  - cell [ref=e320]
                  - cell [ref=e321]
                  - cell [ref=e322]
                  - cell "已取消" [ref=e323]:
                    - generic [ref=e324]: 已取消
                  - cell "-" [ref=e325]
            - list [ref=e326]:
              - listitem "上一页" [ref=e327]:
                - button "left" [disabled] [ref=e328]:
                  - img "left" [ref=e329]:
                    - img [ref=e330]
              - listitem "1" [ref=e332] [cursor=pointer]:
                - generic [ref=e333]: "1"
              - listitem "2" [ref=e334] [cursor=pointer]:
                - generic [ref=e335]: "2"
              - listitem "下一页" [ref=e336] [cursor=pointer]:
                - button "right" [ref=e337]:
                  - img "right" [ref=e338]:
                    - img [ref=e339]
    - generic [ref=e342]:
      - generic [ref=e343]: 慧宿智联 · 智慧酒店管理系统
      - generic [ref=e344]: "|"
      - generic [ref=e345]: 前台端 v2.2.0
```

# Test source

```ts
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
> 104 |       await expect(page.locator('text=前台工作台|接待中心')).toBeVisible();
      |                                                     ^ Error: expect(locator).toBeVisible() failed
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