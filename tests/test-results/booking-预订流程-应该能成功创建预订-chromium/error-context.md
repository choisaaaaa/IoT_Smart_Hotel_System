# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: booking.spec.ts >> 预订流程 >> 应该能成功创建预订
- Location: specs\booking.spec.ts:29:7

# Error details

```
TimeoutError: page.click: Timeout 30000ms exceeded.
Call log:
  - waiting for locator('text=预订管理')

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
        - generic [ref=e34] [cursor=pointer]:
          - img "control" [ref=e35]:
            - img [ref=e36]
          - generic [ref=e38]: 设备管理
        - generic [ref=e39] [cursor=pointer]:
          - img "file-text" [ref=e40]:
            - img [ref=e41]
          - generic [ref=e43]: 服务管理
        - generic [ref=e44] [cursor=pointer]:
          - img "tool" [ref=e45]:
            - img [ref=e46]
          - generic [ref=e48]: 系统设置
        - menuitem "bar-chart 数据报表" [ref=e49] [cursor=pointer]:
          - img "bar-chart" [ref=e50]:
            - img [ref=e51]
          - generic [ref=e53]: 数据报表
  - generic [ref=e54]:
    - generic [ref=e55]:
      - generic [ref=e56]:
        - img "menu-fold" [ref=e57] [cursor=pointer]:
          - img [ref=e58]
        - navigation [ref=e60]:
          - list [ref=e61]:
            - listitem [ref=e62]:
              - generic [ref=e63]: 总览仪表盘
      - generic [ref=e64]:
        - generic [ref=e65]:
          - img "wifi" [ref=e66]:
            - img [ref=e67]
          - generic [ref=e69]: 在线
        - generic [ref=e70] [cursor=pointer]:
          - img "user" [ref=e72]:
            - img [ref=e73]
          - generic [ref=e75]:
            - generic [ref=e76]: 测试门店经理
            - generic [ref=e77]: 酒店管理员
          - img "down" [ref=e78]:
            - img [ref=e79]
    - main [ref=e81]:
      - generic [ref=e82]:
        - generic [ref=e83]:
          - generic [ref=e87] [cursor=pointer]:
            - generic [ref=e88]: 总客房
            - generic [ref=e89]:
              - img "home" [ref=e91]:
                - img [ref=e92]
              - generic [ref=e95]: "10"
              - generic [ref=e96]: 间
          - generic [ref=e100] [cursor=pointer]:
            - generic [ref=e101]: 已入住
            - generic [ref=e102]:
              - img "user" [ref=e104]:
                - img [ref=e105]
              - generic [ref=e108]: "0"
              - generic [ref=e109]: 间
          - generic [ref=e113] [cursor=pointer]:
            - generic [ref=e114]: 设备在线
            - generic [ref=e115]:
              - img "check-circle" [ref=e117]:
                - img [ref=e118]
              - generic [ref=e122]: "1"
          - generic [ref=e126] [cursor=pointer]:
            - generic [ref=e127]: 设备异常
            - generic [ref=e128]:
              - img "warning" [ref=e130]:
                - img [ref=e131]
              - generic [ref=e134]: "0"
        - generic [ref=e135]:
          - generic [ref=e140]: 设备在线状态
          - generic [ref=e146]:
            - generic [ref=e149]: 酒店基本信息
            - table [ref=e153]:
              - rowgroup [ref=e154]:
                - row "酒店名称 ZhiLianHotel" [ref=e155]:
                  - rowheader "酒店名称" [ref=e156]
                  - cell "ZhiLianHotel" [ref=e157]:
                    - generic [ref=e158]: ZhiLianHotel
                - row "星级 5星级" [ref=e159]:
                  - rowheader "星级" [ref=e160]
                  - cell "5星级" [ref=e161]:
                    - generic [ref=e162]: 5星级
                - row "总房间数 3间" [ref=e163]:
                  - rowheader "总房间数" [ref=e164]
                  - cell "3间" [ref=e165]:
                    - generic [ref=e166]: 3间
                - row "入住率" [ref=e167]:
                  - rowheader "入住率" [ref=e168]
                  - cell [ref=e169]:
                    - progressbar [ref=e171]:
                      - generic "0%" [ref=e174]
                - row "地址 Beijing" [ref=e175]:
                  - rowheader "地址" [ref=e176]
                  - cell "Beijing" [ref=e177]:
                    - generic [ref=e178]: Beijing
        - generic [ref=e181]:
          - generic [ref=e184]: 房间状态一览
          - generic [ref=e188]:
            - table [ref=e192]:
              - rowgroup [ref=e200]:
                - row "房号 房型 价格(元/晚) 状态 楼层 面积(m²)" [ref=e201]:
                  - columnheader "房号" [ref=e202]
                  - columnheader "房型" [ref=e203]
                  - columnheader "价格(元/晚)" [ref=e204]
                  - columnheader "状态" [ref=e205]
                  - columnheader "楼层" [ref=e206]
                  - columnheader "面积(m²)" [ref=e207]
              - rowgroup [ref=e208]:
                - row "201 standard 309.00 available 2 32.00" [ref=e209]:
                  - cell "201" [ref=e210]
                  - cell "standard" [ref=e211]
                  - cell "309.00" [ref=e212]
                  - cell "available" [ref=e213]
                  - cell "2" [ref=e214]
                  - cell "32.00" [ref=e215]
                - row "202 standard 279.00 cleaning 2 28.00" [ref=e216]:
                  - cell "202" [ref=e217]
                  - cell "standard" [ref=e218]
                  - cell "279.00" [ref=e219]
                  - cell "cleaning" [ref=e220]
                  - cell "2" [ref=e221]
                  - cell "28.00" [ref=e222]
                - row "203 standard 309.00 available 2 32.00" [ref=e223]:
                  - cell "203" [ref=e224]
                  - cell "standard" [ref=e225]
                  - cell "309.00" [ref=e226]
                  - cell "available" [ref=e227]
                  - cell "2" [ref=e228]
                  - cell "32.00" [ref=e229]
                - row "204 standard 309.00 maintenance 2 32.00" [ref=e230]:
                  - cell "204" [ref=e231]
                  - cell "standard" [ref=e232]
                  - cell "309.00" [ref=e233]
                  - cell "maintenance" [ref=e234]
                  - cell "2" [ref=e235]
                  - cell "32.00" [ref=e236]
                - row "205 standard 309.00 maintenance 2 32.00" [ref=e237]:
                  - cell "205" [ref=e238]
                  - cell "standard" [ref=e239]
                  - cell "309.00" [ref=e240]
                  - cell "maintenance" [ref=e241]
                  - cell "2" [ref=e242]
                  - cell "32.00" [ref=e243]
                - row "206 standard 309.00 available 2 32.00" [ref=e244]:
                  - cell "206" [ref=e245]
                  - cell "standard" [ref=e246]
                  - cell "309.00" [ref=e247]
                  - cell "available" [ref=e248]
                  - cell "2" [ref=e249]
                  - cell "32.00" [ref=e250]
                - row "207 standard 309.00 maintenance 2 32.00" [ref=e251]:
                  - cell "207" [ref=e252]
                  - cell "standard" [ref=e253]
                  - cell "309.00" [ref=e254]
                  - cell "maintenance" [ref=e255]
                  - cell "2" [ref=e256]
                  - cell "32.00" [ref=e257]
                - row "208 standard 279.00 available 2 28.00" [ref=e258]:
                  - cell "208" [ref=e259]
                  - cell "standard" [ref=e260]
                  - cell "279.00" [ref=e261]
                  - cell "available" [ref=e262]
                  - cell "2" [ref=e263]
                  - cell "28.00" [ref=e264]
            - list [ref=e265]:
              - listitem "上一页" [ref=e266]:
                - button "left" [disabled] [ref=e267]:
                  - img "left" [ref=e268]:
                    - img [ref=e269]
              - listitem "1" [ref=e271] [cursor=pointer]:
                - generic [ref=e272]: "1"
              - listitem "2" [ref=e273] [cursor=pointer]:
                - generic [ref=e274]: "2"
              - listitem "下一页" [ref=e275] [cursor=pointer]:
                - button "right" [ref=e276]:
                  - img "right" [ref=e277]:
                    - img [ref=e278]
    - generic [ref=e281]:
      - generic [ref=e282]: ZhiLianHotel
      - generic [ref=e283]: "|"
      - generic [ref=e284]: 管理后台 v2.2.0
```

# Test source

```ts
  1  | import { test, expect } from '@playwright/test';
  2  | 
  3  | /**
  4  |  * 预订模块 E2E 测试
  5  |  * 测试从预订到入住的完整流程
  6  |  */
  7  | 
  8  | test.describe('预订流程', () => {
  9  |   test.beforeEach(async ({ page }) => {
  10 |     // 每个测试前登录为酒店经理 137...
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
  29 |   test('应该能成功创建预订', async ({ page }) => {
  30 |     // 点击预订管理菜单
> 31 |     await page.click('text=预订管理');
     |                ^ TimeoutError: page.click: Timeout 30000ms exceeded.
  32 |     await page.waitForTimeout(1000);
  33 |     
  34 |     await page.click('text=新增预订');
  35 |     await page.waitForTimeout(1000);
  36 |     
  37 |     // 填写预订表单 - 使用普通顾客手机号 139...
  38 |     await page.fill('input[name="guest_name"]', '测试住客');
  39 |     await page.fill('input[name="guest_phone"]', '13999999999');
  40 |     await page.fill('input[name="check_in_date"]', '2026-05-01');
  41 |     await page.fill('input[name="check_out_date"]', '2026-05-03');
  42 |     
  43 |     // 选择房型
  44 |     await page.click('.room-type-selector');
  45 |     await page.click('.ant-select-item:has-text("标准间")');
  46 |     
  47 |     // 提交表单
  48 |     await page.click('button:has-text("确认预订")');
  49 |     
  50 |     // 验证成功提示
  51 |     await expect(page.locator('.ant-message-success')).toContainText('预订成功');
  52 |   });
  53 | 
  54 |   test('应该能够查询预订列表', async ({ page }) => {
  55 |     await page.click('text=预订管理');
  56 |     
  57 |     // 验证预订列表加载
  58 |     await expect(page.locator('.booking-list')).toBeVisible();
  59 |     
  60 |     // 验证表格有数据
  61 |     const rows = page.locator('.ant-table-row');
  62 |     await expect(rows.first()).toBeVisible();
  63 |   });
  64 | 
  65 |   test('应该能够办理入住', async ({ page }) => {
  66 |     await page.click('text=预订管理');
  67 |     
  68 |     // 找到第一个待入住的预订
  69 |     const checkInButton = page.locator('button:has-text("办理入住")').first();
  70 |     
  71 |     if (await checkInButton.isVisible().catch(() => false)) {
  72 |       await checkInButton.click();
  73 |       
  74 |       // 确认入住
  75 |       await page.click('button:has-text("确认")');
  76 |       
  77 |       // 验证成功
  78 |       await expect(page.locator('.ant-message-success')).toContainText('入住成功');
  79 |     }
  80 |   });
  81 | });
  82 | 
```