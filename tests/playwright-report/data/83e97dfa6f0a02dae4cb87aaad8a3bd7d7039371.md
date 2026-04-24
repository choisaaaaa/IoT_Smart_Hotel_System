# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: device.spec.ts >> 设备控制 >> 应该能成功控制设备
- Location: specs\device.spec.ts:39:7

# Error details

```
TimeoutError: locator.waitFor: Timeout 30000ms exceeded.
Call log:
  - waiting for locator('.ant-switch').first() to be visible

```

# Page snapshot

```yaml
- generic [ref=e3]:
  - complementary [ref=e4]:
    - generic [ref=e5]:
      - generic [ref=e6] [cursor=pointer]:
        - img "Logo" [ref=e8]
        - generic [ref=e9]:
          - generic [ref=e10]: 管理后台
          - generic [ref=e11]: ZhiLianHotel
      - menu [ref=e13]:
        - menuitem "dashboard 管理总览" [ref=e14] [cursor=pointer]:
          - img "dashboard" [ref=e15]:
            - img [ref=e16]
          - generic [ref=e18]: 管理总览
        - generic [ref=e19] [cursor=pointer]:
          - img "bank" [ref=e20]:
            - img [ref=e21]
          - generic [ref=e23]: 酒店管理
        - generic [ref=e24] [cursor=pointer]:
          - img "home" [ref=e25]:
            - img [ref=e26]
          - generic [ref=e28]: 客房管理
        - generic [ref=e29] [cursor=pointer]:
          - img "team" [ref=e30]:
            - img [ref=e31]
          - generic [ref=e33]: 用户管理
        - generic [active] [ref=e34] [cursor=pointer]:
          - img "control" [ref=e35]:
            - img [ref=e36]
          - generic [ref=e38]: 设备管理
        - list [ref=e39]:
          - menuitem "设备监控" [ref=e40] [cursor=pointer]:
            - generic [ref=e41]: 设备监控
          - menuitem "设备类型" [ref=e42] [cursor=pointer]:
            - generic [ref=e43]: 设备类型
          - menuitem "设备日志" [ref=e44] [cursor=pointer]:
            - generic [ref=e45]: 设备日志
          - menuitem "待审核设备" [ref=e46] [cursor=pointer]:
            - generic [ref=e47]: 待审核设备
          - menuitem "环境监测" [ref=e48] [cursor=pointer]:
            - generic [ref=e49]: 环境监测
        - generic [ref=e50] [cursor=pointer]:
          - img "file-text" [ref=e51]:
            - img [ref=e52]
          - generic [ref=e54]: 服务管理
        - generic [ref=e55] [cursor=pointer]:
          - img "tool" [ref=e56]:
            - img [ref=e57]
          - generic [ref=e59]: 系统设置
        - menuitem "bar-chart 数据报表" [ref=e60] [cursor=pointer]:
          - img "bar-chart" [ref=e61]:
            - img [ref=e62]
          - generic [ref=e64]: 数据报表
  - generic [ref=e65]:
    - generic [ref=e66]:
      - generic [ref=e67]:
        - img "menu-fold" [ref=e68] [cursor=pointer]:
          - img [ref=e69]
        - navigation [ref=e71]:
          - list [ref=e72]:
            - listitem [ref=e73]:
              - generic [ref=e74]: 总览仪表盘
      - generic [ref=e75]:
        - generic [ref=e76]:
          - img "disconnect" [ref=e77]:
            - img [ref=e78]
          - generic [ref=e80]: 离线
        - generic [ref=e81] [cursor=pointer]:
          - img "user" [ref=e83]:
            - img [ref=e84]
          - generic [ref=e86]:
            - generic [ref=e87]: 测试门店经理
            - generic [ref=e88]: 酒店管理员
          - img "down" [ref=e89]:
            - img [ref=e90]
    - main [ref=e92]:
      - generic [ref=e93]:
        - generic [ref=e94]:
          - generic [ref=e98] [cursor=pointer]:
            - generic [ref=e99]: 总客房
            - generic [ref=e100]:
              - img "home" [ref=e102]:
                - img [ref=e103]
              - generic [ref=e106]: "10"
              - generic [ref=e107]: 间
          - generic [ref=e111] [cursor=pointer]:
            - generic [ref=e112]: 已入住
            - generic [ref=e113]:
              - img "user" [ref=e115]:
                - img [ref=e116]
              - generic [ref=e119]: "0"
              - generic [ref=e120]: 间
          - generic [ref=e124] [cursor=pointer]:
            - generic [ref=e125]: 设备在线
            - generic [ref=e126]:
              - img "check-circle" [ref=e128]:
                - img [ref=e129]
              - generic [ref=e133]: "1"
          - generic [ref=e137] [cursor=pointer]:
            - generic [ref=e138]: 设备异常
            - generic [ref=e139]:
              - img "warning" [ref=e141]:
                - img [ref=e142]
              - generic [ref=e145]: "0"
        - generic [ref=e146]:
          - generic [ref=e151]: 设备在线状态
          - generic [ref=e157]:
            - generic [ref=e160]: 酒店基本信息
            - table [ref=e164]:
              - rowgroup [ref=e165]:
                - row "酒店名称 ZhiLianHotel" [ref=e166]:
                  - rowheader "酒店名称" [ref=e167]
                  - cell "ZhiLianHotel" [ref=e168]:
                    - generic [ref=e169]: ZhiLianHotel
                - row "星级 5星级" [ref=e170]:
                  - rowheader "星级" [ref=e171]
                  - cell "5星级" [ref=e172]:
                    - generic [ref=e173]: 5星级
                - row "总房间数 3间" [ref=e174]:
                  - rowheader "总房间数" [ref=e175]
                  - cell "3间" [ref=e176]:
                    - generic [ref=e177]: 3间
                - row "入住率" [ref=e178]:
                  - rowheader "入住率" [ref=e179]
                  - cell [ref=e180]:
                    - progressbar [ref=e182]:
                      - generic "0%" [ref=e185]
                - row "地址 Beijing" [ref=e186]:
                  - rowheader "地址" [ref=e187]
                  - cell "Beijing" [ref=e188]:
                    - generic [ref=e189]: Beijing
        - generic [ref=e192]:
          - generic [ref=e195]: 房间状态一览
          - generic [ref=e199]:
            - table [ref=e203]:
              - rowgroup [ref=e211]:
                - row "房号 房型 价格(元/晚) 状态 楼层 面积(m²)" [ref=e212]:
                  - columnheader "房号" [ref=e213]
                  - columnheader "房型" [ref=e214]
                  - columnheader "价格(元/晚)" [ref=e215]
                  - columnheader "状态" [ref=e216]
                  - columnheader "楼层" [ref=e217]
                  - columnheader "面积(m²)" [ref=e218]
              - rowgroup [ref=e219]:
                - row "201 standard 309.00 available 2 32.00" [ref=e220]:
                  - cell "201" [ref=e221]
                  - cell "standard" [ref=e222]
                  - cell "309.00" [ref=e223]
                  - cell "available" [ref=e224]
                  - cell "2" [ref=e225]
                  - cell "32.00" [ref=e226]
                - row "202 standard 279.00 cleaning 2 28.00" [ref=e227]:
                  - cell "202" [ref=e228]
                  - cell "standard" [ref=e229]
                  - cell "279.00" [ref=e230]
                  - cell "cleaning" [ref=e231]
                  - cell "2" [ref=e232]
                  - cell "28.00" [ref=e233]
                - row "203 standard 309.00 available 2 32.00" [ref=e234]:
                  - cell "203" [ref=e235]
                  - cell "standard" [ref=e236]
                  - cell "309.00" [ref=e237]
                  - cell "available" [ref=e238]
                  - cell "2" [ref=e239]
                  - cell "32.00" [ref=e240]
                - row "204 standard 309.00 maintenance 2 32.00" [ref=e241]:
                  - cell "204" [ref=e242]
                  - cell "standard" [ref=e243]
                  - cell "309.00" [ref=e244]
                  - cell "maintenance" [ref=e245]
                  - cell "2" [ref=e246]
                  - cell "32.00" [ref=e247]
                - row "205 standard 309.00 maintenance 2 32.00" [ref=e248]:
                  - cell "205" [ref=e249]
                  - cell "standard" [ref=e250]
                  - cell "309.00" [ref=e251]
                  - cell "maintenance" [ref=e252]
                  - cell "2" [ref=e253]
                  - cell "32.00" [ref=e254]
                - row "206 standard 309.00 available 2 32.00" [ref=e255]:
                  - cell "206" [ref=e256]
                  - cell "standard" [ref=e257]
                  - cell "309.00" [ref=e258]
                  - cell "available" [ref=e259]
                  - cell "2" [ref=e260]
                  - cell "32.00" [ref=e261]
                - row "207 standard 309.00 maintenance 2 32.00" [ref=e262]:
                  - cell "207" [ref=e263]
                  - cell "standard" [ref=e264]
                  - cell "309.00" [ref=e265]
                  - cell "maintenance" [ref=e266]
                  - cell "2" [ref=e267]
                  - cell "32.00" [ref=e268]
                - row "208 standard 279.00 available 2 28.00" [ref=e269]:
                  - cell "208" [ref=e270]
                  - cell "standard" [ref=e271]
                  - cell "279.00" [ref=e272]
                  - cell "available" [ref=e273]
                  - cell "2" [ref=e274]
                  - cell "28.00" [ref=e275]
            - list [ref=e276]:
              - listitem "上一页" [ref=e277]:
                - button "left" [disabled] [ref=e278]:
                  - img "left" [ref=e279]:
                    - img [ref=e280]
              - listitem "1" [ref=e282] [cursor=pointer]:
                - generic [ref=e283]: "1"
              - listitem "2" [ref=e284] [cursor=pointer]:
                - generic [ref=e285]: "2"
              - listitem "下一页" [ref=e286] [cursor=pointer]:
                - button "right" [ref=e287]:
                  - img "right" [ref=e288]:
                    - img [ref=e289]
    - generic [ref=e292]:
      - generic [ref=e293]: ZhiLianHotel
      - generic [ref=e294]: "|"
      - generic [ref=e295]: 管理后台 v2.2.0
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
  26 |     await page.waitForURL(/.*hotel-admin.*/, { timeout: 30000 });
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
> 46 |     await switchBtn.waitFor({ state: 'visible' });
     |                     ^ TimeoutError: locator.waitFor: Timeout 30000ms exceeded.
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