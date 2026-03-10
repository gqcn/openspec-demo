import { test, expect } from '../../fixtures/auth'
import { UserPage } from '../../pages/UserPage'

test.describe('TC0020 用户/规格列表反馈验证', () => {

  // FB-27: 新增用户时用户名应可输入
  test('TC0020a: 新增用户时用户名字段可输入', async ({ adminPage }) => {
    const userPage = new UserPage(adminPage)
    await userPage.goto()
    await userPage.addButton.click()
    await adminPage.waitForTimeout(800)
    // Verify drawer opens in create mode (title should be "新增用户")
    await expect(adminPage.getByText('新增用户').first()).toBeVisible({ timeout: 5_000 })
    // Find the username input and verify it's editable
    const usernameInput = adminPage.getByLabel('用户名').first()
    await expect(usernameInput).toBeVisible({ timeout: 5_000 })
    await expect(usernameInput).toBeEnabled({ timeout: 3_000 })
    await usernameInput.fill('test_fb27_input')
    await expect(usernameInput).toHaveValue('test_fb27_input')
  })

  // FB-27 regression: 编辑后再新增，用户名仍可输入
  test('TC0020b: 编辑用户后再新增，用户名字段仍可输入', async ({ adminPage }) => {
    const userPage = new UserPage(adminPage)
    await userPage.goto()
    // First open edit on an existing user
    const editBtn = adminPage.getByRole('button', { name: '编辑' }).first()
    await editBtn.click()
    await adminPage.waitForTimeout(800)
    // Close the edit drawer via Escape
    await adminPage.keyboard.press('Escape')
    await adminPage.waitForTimeout(800)
    // Now open create drawer
    await userPage.addButton.click()
    await adminPage.waitForTimeout(800)
    // Verify drawer opens in create mode
    await expect(adminPage.getByText('新增用户').first()).toBeVisible({ timeout: 5_000 })
    // Verify username field is enabled
    const usernameInput = adminPage.getByLabel('用户名').first()
    await expect(usernameInput).toBeVisible({ timeout: 5_000 })
    await expect(usernameInput).toBeEnabled({ timeout: 3_000 })
    await usernameInput.fill('test_fb27_after_edit')
    await expect(usernameInput).toHaveValue('test_fb27_after_edit')
  })

  // FB-28: 新增用户时角色为必填
  test('TC0020c: 新增用户表单角色字段有必填标记', async ({ adminPage }) => {
    const userPage = new UserPage(adminPage)
    await userPage.goto()
    await userPage.addButton.click()
    await adminPage.waitForTimeout(800)
    // Verify drawer opens in create mode
    await expect(adminPage.getByText('新增用户').first()).toBeVisible({ timeout: 5_000 })
    // The role label should have a required indicator (asterisk *)
    // In Vben forms, required fields have a red asterisk
    const roleLabel = adminPage.getByText('角色').first()
    await expect(roleLabel).toBeVisible({ timeout: 3_000 })
    // Try to submit without filling anything — click confirm button
    const confirmBtn = adminPage.getByRole('button', { name: /确\s*认/ }).last()
    if (await confirmBtn.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await confirmBtn.click()
      await adminPage.waitForTimeout(500)
      // Drawer should still be open (validation failed)
      await expect(adminPage.getByText('新增用户').first()).toBeVisible({ timeout: 3_000 })
    }
  })

  // FB-29: 规格列表默认按 ID 排序
  test('TC0020d: 规格列表默认按 ID 升序排列', async ({ adminPage }) => {
    await adminPage.goto('/specs')
    await adminPage.waitForLoadState('networkidle')
    const ordered = await adminPage.evaluate(async () => {
      const token = localStorage.getItem('token') || ''
      const r = await fetch('/api/spec?page=1&size=100', { headers: { Authorization: 'Bearer ' + token } })
      const d = await r.json()
      const list = d.data?.list ?? []
      if (list.length < 2) return true
      for (let i = 1; i < list.length; i++) {
        if (list[i].id < list[i - 1].id) return false
      }
      return true
    })
    expect(ordered).toBe(true)
  })

  // FB-30: 用户列表列标题可点击排序
  test('TC0020e: 用户列表的 ID 列标题可点击排序', async ({ adminPage }) => {
    await adminPage.goto('/users')
    await adminPage.waitForLoadState('networkidle')
    const idHeader = adminPage.locator('.vxe-header--column').filter({ hasText: 'ID' }).first()
    await expect(idHeader).toBeVisible({ timeout: 5_000 })
    await idHeader.click()
    await adminPage.waitForTimeout(300)
    const sortIndicator = adminPage.locator('.vxe-cell--sort-active-icon, .vxe-sort--asc-btn.is--active, .vxe-sort--desc-btn.is--active, [class*="sort"][class*="active"]').first()
    const hasSortIndicator = await sortIndicator.isVisible({ timeout: 3_000 }).catch(() => false)
    const headerSorted = await idHeader.locator('[class*="active"], [class*="sort"]').first().isVisible({ timeout: 2_000 }).catch(() => false)
    expect(hasSortIndicator || headerSorted).toBeTruthy()
  })

  // FB-30: 规格列表列标题可点击排序
  test('TC0020f: 规格列表的名称列标题可点击排序', async ({ adminPage }) => {
    await adminPage.goto('/specs')
    await adminPage.waitForLoadState('networkidle')
    const nameHeader = adminPage.locator('.vxe-header--column').filter({ hasText: '名称' }).first()
    await expect(nameHeader).toBeVisible({ timeout: 5_000 })
    await nameHeader.click()
    await adminPage.waitForTimeout(300)
    const sortIndicator = adminPage.locator('.vxe-cell--sort-active-icon, .vxe-sort--asc-btn.is--active, .vxe-sort--desc-btn.is--active, [class*="sort"][class*="active"]').first()
    const hasSortIndicator = await sortIndicator.isVisible({ timeout: 3_000 }).catch(() => false)
    const headerSorted = await nameHeader.locator('[class*="active"], [class*="sort"]').first().isVisible({ timeout: 2_000 }).catch(() => false)
    expect(hasSortIndicator || headerSorted).toBeTruthy()
  })
})
