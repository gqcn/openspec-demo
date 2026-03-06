import { test, expect } from '../../fixtures/auth'
import { LoginPage } from '../../pages/LoginPage'
import { config } from '../../fixtures/config'

test.describe('TC-1 登录验证', () => {
  test('TC-1a: 登录后跳转到 /notebooks', async ({ page }) => {
    const loginPage = new LoginPage(page)
    await loginPage.goto()
    await loginPage.loginAndWaitForRedirect(config.adminUser, config.adminPass)
    expect(page.url()).toContain('/notebooks')
  })

  test('TC-1b: 侧边栏显示管理员菜单', async ({ adminPage }) => {
    await expect(adminPage.getByText('规格管理')).toBeVisible()
  })

  test('TC-1c: 顶部显示用户名', async ({ adminPage }) => {
    await expect(adminPage.getByText('admin')).toBeVisible()
  })
})

test.describe('TC-7 退出登录', () => {
  test('TC-7a: 退出登录后跳转到 /login', async ({ adminPage, mainLayout }) => {
    await mainLayout.logout(config.adminUser)
    expect(adminPage.url()).toContain('/login')
  })

  test('TC-7c: 退出后显示登录表单', async ({ adminPage, mainLayout }) => {
    await mainLayout.logout(config.adminUser)
    await expect(adminPage.getByRole('button', { name: '登 录' })).toBeVisible({ timeout: 8_000 })
  })

  test('TC-7d: 未登录访问 /notebooks 重定向到 /login', async ({ adminPage, mainLayout }) => {
    await mainLayout.logout(config.adminUser)
    await adminPage.goto('/notebooks')
    await adminPage.waitForURL('**/login', { timeout: 5_000 })
    expect(adminPage.url()).toContain('/login')
  })

  test('TC-7e: 错误密码不崩溃，留在登录页', async ({ page }) => {
    const loginPage = new LoginPage(page)
    await loginPage.goto()
    await loginPage.login('admin', 'wrong_password_!@#')

    // Should stay on login page
    await page.waitForTimeout(2_000)
    expect(page.url()).toContain('/login')
  })

  test('TC-7f: 错误密码显示错误提示', async ({ page }) => {
    const loginPage = new LoginPage(page)
    await loginPage.goto()
    await loginPage.login('admin', 'wrong_password_!@#')

    // Wait for error message (el-message or el-message--error)
    const errorVisible = await page.locator('.el-message--error, .el-message').first()
      .waitFor({ state: 'visible', timeout: 5_000 })
      .then(() => true)
      .catch(() => false)
    expect(errorVisible).toBeTruthy()
  })
})
