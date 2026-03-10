import { test, expect } from '../../fixtures/auth'
import { LoginPage } from '../../pages/LoginPage'

test.describe('TC0019 UI 清理反馈验证', () => {

  // FB-22: 用户头像下拉中不应展示"AI开发训练平台"标签
  test('TC0019a: 用户下拉菜单不包含"AI开发训练平台"标签', async ({ adminPage }) => {
    // Click avatar to open dropdown
    const avatar = adminPage.locator('.cursor-pointer').filter({ has: adminPage.locator('.size-8') }).first()
    await avatar.click()
    await adminPage.waitForTimeout(500)
    // The dropdown content area (shadcn DropdownMenuContent)
    const dropdownContent = adminPage.locator('[role="menu"], [data-radix-menu-content]').first()
    await expect(dropdownContent).toBeVisible({ timeout: 5_000 })
    // Within the dropdown, there should be no Badge with "AI开发训练平台"
    const badgeInDropdown = dropdownContent.locator('text=AI开发训练平台')
    await expect(badgeInDropdown).not.toBeVisible({ timeout: 3_000 })
  })

  // FB-23: 用户列表和规格列表的表格应填充满整个宽度
  test('TC0019b: 规格列表表格宽度应填充容器', async ({ adminPage }) => {
    await adminPage.goto('/specs')
    await adminPage.waitForLoadState('networkidle')
    const table = adminPage.locator('.vxe-table, .vxe-grid').first()
    await expect(table).toBeVisible({ timeout: 10_000 })
    const container = adminPage.locator('.page-content, main, [class*="content"]').first()
    const tableBox = await table.boundingBox()
    const containerBox = await container.boundingBox()
    if (tableBox && containerBox) {
      const ratio = tableBox.width / containerBox.width
      expect(ratio).toBeGreaterThan(0.9)
    }
  })

  test('TC0019c: 用户列表表格宽度应填充容器', async ({ adminPage }) => {
    await adminPage.goto('/users')
    await adminPage.waitForLoadState('networkidle')
    const table = adminPage.locator('.vxe-table, .vxe-grid').first()
    await expect(table).toBeVisible({ timeout: 10_000 })
    const container = adminPage.locator('.page-content, main, [class*="content"]').first()
    const tableBox = await table.boundingBox()
    const containerBox = await container.boundingBox()
    if (tableBox && containerBox) {
      const ratio = tableBox.width / containerBox.width
      expect(ratio).toBeGreaterThan(0.9)
    }
  })

  // FB-24: 用户列表和规格列表不应有搜索框
  test('TC0019d: 规格列表页面无搜索框', async ({ adminPage }) => {
    await adminPage.goto('/specs')
    await adminPage.waitForLoadState('networkidle')
    const searchForm = adminPage.locator('.vxe-grid--form-wrapper form, .vxe-form')
    await expect(searchForm).not.toBeVisible({ timeout: 5_000 })
  })

  test('TC0019e: 用户列表页面无搜索框', async ({ adminPage }) => {
    await adminPage.goto('/users')
    await adminPage.waitForLoadState('networkidle')
    const searchForm = adminPage.locator('.vxe-grid--form-wrapper form, .vxe-form')
    await expect(searchForm).not.toBeVisible({ timeout: 5_000 })
  })

  // FB-25: 登录页底部版权信息不应包含"Vben"
  test('TC0019f: 登录页不包含 Vben 版权信息', async ({ page }) => {
    const loginPage = new LoginPage(page)
    await loginPage.goto()
    await page.waitForLoadState('networkidle')
    const vbenText = page.getByText('Vben', { exact: false })
    await expect(vbenText).not.toBeVisible({ timeout: 5_000 })
  })

  // FB-26: 偏好设置面板中"布局"下不应有"版权"设置
  test('TC0019g: 偏好设置面板中无版权设置区块', async ({ adminPage }) => {
    // Find and click the preferences settings button
    const settingsBtn = adminPage.locator('[class*="preferences"], [title*="偏好设置"]').first()
    if (await settingsBtn.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await settingsBtn.click()
    } else {
      const fixedBtn = adminPage.locator('.fixed button, [class*="rounded-l-lg"]').first()
      if (await fixedBtn.isVisible({ timeout: 3_000 }).catch(() => false)) {
        await fixedBtn.click()
      }
    }
    await adminPage.waitForTimeout(1_500)
    // Check copyright setting is not visible in preferences drawer
    const copyrightSection = adminPage.getByText('版权', { exact: false })
    await expect(copyrightSection).not.toBeVisible({ timeout: 5_000 })
  })
})
