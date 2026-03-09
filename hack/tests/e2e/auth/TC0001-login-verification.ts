import { test, expect } from '../../fixtures/auth'
import { LoginPage } from '../../pages/LoginPage'
import { config } from '../../fixtures/config'

test.describe('TC0001 登录验证', () => {
  test('TC0001a: 登录后跳转到 /notebooks', async ({ page }) => {
    const loginPage = new LoginPage(page)
    await loginPage.goto()
    await loginPage.loginAndWaitForRedirect(config.adminUser, config.adminPass)
    expect(page.url()).toContain('/notebooks')
  })

  test('TC0001b: 侧边栏显示管理员菜单', async ({ adminPage }) => {
    await expect(adminPage.getByText('规格管理')).toBeVisible()
  })

  test('TC0001c: 顶部显示用户名', async ({ adminPage }) => {
    await expect(adminPage.getByText('admin')).toBeVisible()
  })
})
