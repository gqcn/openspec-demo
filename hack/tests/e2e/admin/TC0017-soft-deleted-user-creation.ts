import { test, expect } from '../../fixtures/auth'
import { UserPage } from '../../pages/UserPage'

test.describe('TC-17 软删除用户重名创建', () => {
  const uniqueName = `softdel_${Date.now()}`.slice(0, 32)
  const password = 'Test@123456'

  test('TC-17a: 创建用户→删除→再次创建同名用户应返回友好错误而非 SQL 异常', async ({ adminPage }) => {
    const userPage = new UserPage(adminPage)
    await userPage.goto()

    // Step 1: Create a user
    await userPage.createUser(uniqueName, password)
    await userPage.goto()
    await expect(adminPage.getByText(uniqueName)).toBeVisible({ timeout: 5_000 })

    // Step 2: Delete the user (soft-delete)
    await userPage.deleteUser(uniqueName)
    await userPage.goto()
    // User should no longer appear in the list
    await expect(adminPage.getByText(uniqueName)).not.toBeVisible({ timeout: 5_000 })

    // Step 3: Try to create the same username again — should get a friendly error, not SQL error
    const result = await adminPage.evaluate(async ({ username, pass }) => {
      const token = localStorage.getItem('token') || ''
      const r = await fetch('/api/user', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
        body: JSON.stringify({ username, password: pass, isAdmin: 0 }),
      })
      return r.json()
    }, { username: uniqueName, pass: password })

    // Should be a business error (code != 0), not a 500 SQL error
    expect(result.code).not.toBe(0)
    // The message should be user-friendly, not contain SQL error details
    expect(result.message).not.toMatch(/sql|duplicate|syntax/i)
    expect(result.message).toContain('用户名已存在')
  })
})
