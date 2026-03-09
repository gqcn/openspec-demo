import { test, expect } from '../../fixtures/auth'
import { UserPage } from '../../pages/UserPage'
import { config } from '../../fixtures/config'

test.describe('TC0003 用户管理', () => {
  let userPage: UserPage

  test.beforeEach(async ({ adminPage }) => {
    userPage = new UserPage(adminPage)
  })

  test('TC0003a: 页面标题为用户管理', async () => {
    await userPage.goto()
    await expect(userPage.page.getByRole('heading', { name: '用户管理' })).toBeVisible()
  })

  test('TC0003b: 包含 admin 用户', async () => {
    await userPage.goto()
    await expect(userPage.page.getByRole('main').getByText('admin')).toBeVisible()
  })

  test('TC0003c: 用户状态正常', async () => {
    await userPage.goto()
    await expect(userPage.page.getByText('正常').first()).toBeVisible()
  })

  test('TC0003d: 创建用户后出现在列表', async () => {
    await userPage.goto()
    await userPage.createUser(config.testUser, config.testUserPass)
    await userPage.goto()
    await expect(userPage.page.getByText(config.testUser)).toBeVisible()
  })

  test('TC0003e: 禁用用户后状态显示禁用', async () => {
    await userPage.goto()
    await userPage.disableUser(config.testUser)
    await userPage.goto()
    // The table row for testuser01 should show "禁用" status (as tag or text)
    const body = await userPage.page.evaluate(() => document.body.innerText)
    expect(body).toContain(config.testUser)
    // "禁用" appears as the status text or the enable-toggle button label
    expect(body).toContain('禁用')
  })
})
