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
    // Use a unique username to avoid collision with soft-deleted entries
    const uniqueUser = `tc3d_${Date.now()}`.slice(0, 32)
    await userPage.createUser(uniqueUser, config.testUserPass)
    await userPage.goto()
    // Verify via API (pagination-safe)
    const found = await userPage.page.evaluate(async (username) => {
      const token = localStorage.getItem('token') || ''
      const r = await fetch('/api/user?page=1&size=1000', { headers: { Authorization: 'Bearer ' + token } })
      const d = await r.json()
      return (d.data?.list ?? []).some((u: any) => u.username === username)
    }, uniqueUser)
    expect(found).toBe(true)
    // Cleanup
    await userPage.deleteUser(uniqueUser)
  })

  test('TC0003e: 禁用用户后状态显示禁用', async () => {
    await userPage.goto()
    // Create a fresh user to test disable
    const uniqueUser = `tc3e_${Date.now()}`.slice(0, 32)
    await userPage.createUser(uniqueUser, config.testUserPass)
    await userPage.goto()
    await userPage.disableUser(uniqueUser)
    await userPage.goto()
    // Verify via API
    const status = await userPage.page.evaluate(async (username) => {
      const token = localStorage.getItem('token') || ''
      const r = await fetch('/api/user?page=1&size=1000', { headers: { Authorization: 'Bearer ' + token } })
      const d = await r.json()
      const user = (d.data?.list ?? []).find((u: any) => u.username === username)
      return user?.status
    }, uniqueUser)
    expect(status).toBe(0)
    // Cleanup
    await userPage.deleteUser(uniqueUser)
  })

  test('TC0003f: 新增用户对话框中不包含 UID 输入字段', async () => {
    await userPage.goto()
    await userPage.addButton.click()
    await userPage.page.waitForSelector('.el-dialog__body', { timeout: 4_000 })

    // The dialog should not contain a UID form item
    const dialogBody = userPage.page.locator('.el-dialog__body')
    await expect(dialogBody.getByText('UID')).not.toBeVisible()

    // Close the dialog
    await userPage.page.getByRole('button', { name: '取消' }).click()
  })

  test('TC0003g: 用户名格式不合法时前端显示校验错误且不调用 API', async () => {
    await userPage.goto()
    await userPage.addButton.click()
    await userPage.page.waitForSelector('.el-dialog__body', { timeout: 4_000 })

    const dialog = userPage.page.locator('.el-dialog__body')

    // Fill an invalid username (pure numeric — fails Linux username rules)
    await userPage.usernameInput.fill('123')
    await userPage.usernameInput.blur()

    // Frontend validation error should appear
    const errMsg = dialog.locator('.el-form-item__error')
    await expect(errMsg).toBeVisible({ timeout: 3_000 })
    const errText = await errMsg.innerText()
    expect(errText.length).toBeGreaterThan(0)

    // Clicking "创建" should NOT dismiss the dialog (API not called, dialog stays open)
    await userPage.page.getByRole('button', { name: '创建' }).click()
    await expect(userPage.page.locator('.el-dialog')).toBeVisible()

    // Close the dialog
    await userPage.page.getByRole('button', { name: '取消' }).click()
  })

  test('TC0003h: 用户名格式不合法时后端返回错误（纯数字、含大写、含空格）', async () => {
    const invalidNames = ['123', 'UserName', 'user name']
    for (const name of invalidNames) {
      // Attempt creation via UI — dialog validation should block before API, but
      // we also verify backend rejects it by calling the API helper directly.
      const resp = await userPage.page.evaluate(async (username) => {
        const token = localStorage.getItem('token') ?? ''
        const r = await fetch('/api/user', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
          body: JSON.stringify({ username, password: 'Test@123456', isAdmin: 0 }),
        })
        return r.json()
      }, name)
      expect(resp.code, `Backend should reject username "${name}"`).not.toBe(0)
    }

    // A valid username should succeed
    const validName = `e2etest_${Date.now()}`.slice(0, 32)
    const resp = await userPage.page.evaluate(async (username) => {
      const token = localStorage.getItem('token') ?? ''
      const r = await fetch('/api/user', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ username, password: 'Test@123456', isAdmin: 0 }),
      })
      return r.json()
    }, validName)
    expect(resp.code, `Backend should accept valid username "${validName}"`).toBe(0)

    // Cleanup: delete the created test user (best-effort)
    await userPage.goto()
    await userPage.deleteUser(validName)
  })

  test('TC0003i: 用户列表创建时间列有数据', async ({ adminPage }) => {
    const userPage = new UserPage(adminPage)
    await userPage.goto()
    // admin user should always exist — verify its createdAt is non-empty
    const rows = adminPage.locator('tr')
    const adminRow = rows.filter({ hasText: 'admin' })
    const createdAtCell = adminRow.locator('td').nth(5) // "创建时间" column (0-indexed: id,username,uid,role,status,createdAt)
    const text = await createdAtCell.innerText()
    expect(text.trim()).toMatch(/\d{4}-\d{2}-\d{2}/)
  })
})
