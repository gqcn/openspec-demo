import { test, expect } from '../../fixtures/auth'
import { UserPage } from '../../pages/UserPage'

/**
 * TC0014 — Admin can edit a user's role and password.
 *
 * Sub-assertions (all within one test to share tempUser state):
 *   TC0014a — Create temp user, verify it appears in list
 *   TC0014b — Edit role to admin, verify list shows 管理员
 *   TC0014c — Edit role back to 普通用户, verify list updates
 *   TC0014d — Change password, verify new password works via API
 *   TC0014e — Old password is rejected after password change
 */
test('TC0014 用户编辑功能', async ({ adminPage }) => {
  const tempUser = `e2e_edit_${Date.now()}`.slice(0, 32)
  const initialPass = 'InitialPass1!'
  const newPass = 'UpdatedPass2@'
  const userPage = new UserPage(adminPage)

  // ── TC0014a — Create temp user ──
  await userPage.goto()
  await userPage.createUser(tempUser, initialPass)
  await userPage.goto()
  await expect(adminPage.getByText(tempUser)).toBeVisible()

  // ── TC0014b — Edit role to admin ──
  await userPage.editUser(tempUser, { isAdmin: 1 })
  await userPage.goto()
  const rows = adminPage.locator('tr')
  await expect(rows.filter({ hasText: tempUser }).getByText('管理员')).toBeVisible({ timeout: 5_000 })

  // ── TC0014c — Edit role back to 普通用户 ──
  await userPage.editUser(tempUser, { isAdmin: 0 })
  await userPage.goto()
  await expect(rows.filter({ hasText: tempUser }).getByText('普通用户')).toBeVisible({ timeout: 5_000 })

  // ── TC0014d — Change password, new password works ──
  await userPage.editUser(tempUser, { password: newPass })
  const loginNew = await adminPage.evaluate(
    async ({ user, pass }) => {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: user, password: pass }),
      })
      return (await res.json()).code
    },
    { user: tempUser, pass: newPass },
  )
  expect(loginNew).toBe(0)

  // ── TC0014e — Old password rejected ──
  const loginOld = await adminPage.evaluate(
    async ({ user, pass }) => {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: user, password: pass }),
      })
      return (await res.json()).code
    },
    { user: tempUser, pass: initialPass },
  )
  expect(loginOld).not.toBe(0)

  // Cleanup
  await userPage.goto()
  await userPage.deleteUser(tempUser)
})

