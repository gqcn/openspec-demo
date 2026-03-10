import { test, expect } from '../../fixtures/auth'
import { UserPage } from '../../pages/UserPage'

/**
 * TC0015 — Admin can soft-delete a user.
 * After deletion, the user must not appear in the list and cannot log in.
 */
test.describe('TC0015 用户软删除功能', () => {
  const tempUser = `e2e_del_${Date.now()}`.slice(0, 32)
  const tempPass = 'DeleteMe123!'

  test('TC0015a~c: 创建、删除用户后列表不可见且不可登录', async ({ adminPage }) => {
    const userPage = new UserPage(adminPage)

    // ── Step 1: Create temp user ──
    await userPage.goto()
    await userPage.createUser(tempUser, tempPass)
    await userPage.goto()
    await expect(adminPage.getByText(tempUser)).toBeVisible()

    // ── Step 2: TC0015a — verify user can log in before deletion ──
    const beforeDelete = await adminPage.evaluate(
      async ({ user, pass }) => {
        const res = await fetch('/api/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username: user, password: pass }),
        })
        const data = await res.json()
        return data.code
      },
      { user: tempUser, pass: tempPass },
    )
    expect(beforeDelete).toBe(0)

    // ── Step 3: TC0015b — delete the user ──
    await userPage.goto()
    await userPage.deleteUser(tempUser)
    await userPage.goto()
    const body = await adminPage.evaluate(() => document.body.innerText)
    expect(body).not.toContain(tempUser)

    // ── Step 4: TC0015c — deleted user cannot log in ──
    const afterDelete = await adminPage.evaluate(
      async ({ user, pass }) => {
        const res = await fetch('/api/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username: user, password: pass }),
        })
        const data = await res.json()
        return data.code
      },
      { user: tempUser, pass: tempPass },
    )
    expect(afterDelete).not.toBe(0)
  })

  test('TC0015d: 主管理员账号不能被删除', async ({ adminPage }) => {
    const result = await adminPage.evaluate(async () => {
      const token = localStorage.getItem('token') || ''
      const res = await fetch('/api/user/1', {
        method: 'DELETE',
        headers: { Authorization: 'Bearer ' + token },
      })
      const data = await res.json()
      return data.code
    })
    expect(result).not.toBe(0)
  })
})
