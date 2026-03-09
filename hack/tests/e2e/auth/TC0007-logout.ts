import { test, expect } from '../../fixtures/auth'
import { LoginPage } from '../../pages/LoginPage'
import { config } from '../../fixtures/config'

test.describe('TC0007 退出登录', () => {
  test('TC0007a: 退出登录后跳转到 /login', async ({ adminPage, mainLayout }) => {
    await mainLayout.logout(config.adminUser)
    expect(adminPage.url()).toContain('/login')
  })

  test('TC0007c: 退出后显示登录表单', async ({ adminPage, mainLayout }) => {
    await mainLayout.logout(config.adminUser)
    await expect(adminPage.getByRole('button', { name: '登 录' })).toBeVisible({ timeout: 8_000 })
  })

  test('TC0007d: 未登录访问 /notebooks 重定向到 /login', async ({ adminPage, mainLayout }) => {
    await mainLayout.logout(config.adminUser)
    await adminPage.goto('/notebooks')
    await adminPage.waitForURL('**/login', { timeout: 5_000 })
    expect(adminPage.url()).toContain('/login')
  })

  test('TC0007e: 错误密码不崩溃，留在登录页', async ({ page }) => {
    const loginPage = new LoginPage(page)
    await loginPage.goto()
    await loginPage.login('admin', 'wrong_password_!@#')

    // Should stay on login page
    await page.waitForTimeout(2_000)
    expect(page.url()).toContain('/login')
  })

  test('TC0007f: 错误密码显示错误提示', async ({ page }) => {
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
