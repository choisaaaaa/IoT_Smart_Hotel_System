# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: device.spec.ts >> 设备控制 >> 应该能够切换睡眠模式
- Location: specs\device.spec.ts:54:7

# Error details

```
TimeoutError: page.waitForURL: Timeout 30000ms exceeded.
=========================== logs ===========================
waiting for navigation until "load"
============================================================
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
                  - generic [ref=e342]:
                    - img "mobile" [ref=e344]:
                      - img [ref=e345]
                    - textbox "* 手机号码" [ref=e347]:
                      - /placeholder: 请输入手机号
                      - text: "13777777777"
                - generic [ref=e349]:
                  - generic "登录密码" [ref=e351]: "* 登录密码"
                  - generic [ref=e355]:
                    - img "lock" [ref=e357]:
                      - img [ref=e358]
                    - textbox "* 登录密码" [ref=e360]:
                      - /placeholder: 请输入密码
                      - text: password123
                    - img "eye-invisible" [ref=e362] [cursor=pointer]:
                      - img [ref=e363]
                - button "登 录" [active] [ref=e371] [cursor=pointer]:
                  - generic [ref=e372]: 登 录
                - generic [ref=e373]: 还没有账号？立即注册
```

# Test source

```ts
  1  | import { test, expect } from '@playwright/test';
  2  | 
  3  | /**
  4  |  * 设备控制 E2E 测试
  5  |  * 测试 IoT 设备控制功能
  6  |  */
  7  | 
  8  | test.describe('设备控制', () => {
  9  |   test.beforeEach(async ({ page }) => {
  10 |     // 登录为酒店经理 137...
  11 |     await page.goto('/guest/booking');
  12 |     await page.waitForLoadState('networkidle');
  13 |     await page.waitForTimeout(2000);
  14 |     
  15 |     const loginModal = page.locator('.login-modal');
  16 |     if (!await loginModal.isVisible()) {
  17 |       await page.click('.login-btn');
  18 |     }
  19 |     
  20 |     await page.waitForTimeout(1000);
  21 |     await page.getByPlaceholder('请输入手机号').fill('13777777777');
  22 |     await page.waitForTimeout(500);
  23 |     await page.getByPlaceholder('请输入密码').fill('password123');
  24 |     await page.waitForTimeout(500);
  25 |     await page.click('button[type="submit"]');
> 26 |     await page.waitForURL(/.*hotel-admin.*/, { timeout: 30000 });
     |                ^ TimeoutError: page.waitForURL: Timeout 30000ms exceeded.
  27 |   });
  28 | 
  29 |   test('应该显示设备列表', async ({ page }) => {
  30 |     await page.click('text=设备管理');
  31 |     
  32 |     // 验证设备列表页面
  33 |     await expect(page.locator('.device-list')).toBeVisible();
  34 |     
  35 |     // 验证设备卡片或表格
  36 |     await expect(page.locator('.device-card, .ant-table')).toBeVisible();
  37 |   });
  38 | 
  39 |   test('应该能成功控制设备', async ({ page }) => {
  40 |     // 点击设备管理菜单
  41 |     await page.click('text=设备管理');
  42 |     await page.waitForTimeout(2000);
  43 |     
  44 |     // 查找第一个设备的开关按钮并点击
  45 |     const switchBtn = page.locator('.ant-switch').first();
  46 |     await switchBtn.waitFor({ state: 'visible' });
  47 |     await switchBtn.click();
  48 |     await page.waitForTimeout(1000);
  49 |     
  50 |     // 验证成功提示
  51 |     await expect(page.locator('.ant-message-success')).toBeVisible({ timeout: 20000 });
  52 |   });
  53 | 
  54 |   test('应该能够切换睡眠模式', async ({ page }) => {
  55 |     await page.click('text=设备管理');
  56 |     
  57 |     // 查找睡眠模式按钮
  58 |     const sleepModeButton = page.locator('button:has-text("睡眠模式")');
  59 |     
  60 |     if (await sleepModeButton.isVisible().catch(() => false)) {
  61 |       await sleepModeButton.click();
  62 |       
  63 |       // 验证确认对话框
  64 |       await expect(page.locator('.ant-modal')).toContainText('确认');
  65 |       
  66 |       // 确认切换
  67 |       await page.click('.ant-modal .ant-btn-primary');
  68 |       
  69 |       // 验证成功提示
  70 |       await expect(page.locator('.ant-message-success')).toContainText('模式切换成功');
  71 |     }
  72 |   });
  73 | });
  74 | 
```