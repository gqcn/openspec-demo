import { type Page, type Locator } from '@playwright/test'

/**
 * UserPage — /users (用户管理)
 */
export class UserPage {
  readonly page: Page
  readonly addButton: Locator
  readonly usernameInput: Locator

  constructor(page: Page) {
    this.page = page
    this.addButton = page.getByRole('button', { name: '新增用户' })
    this.usernameInput = page.getByPlaceholder('请输入用户名')
  }

  async goto() {
    await this.page.goto('/users')
    await this.page.waitForLoadState('networkidle')
  }

  /** Create a new user. */
  async createUser(username: string, password: string) {
    await this.addButton.click()
    await this.page.waitForSelector('.el-dialog__body', { timeout: 4_000 })
    await this.usernameInput.fill(username)
    await this.page.locator('[type="password"]').first().fill(password)
    await this.page.getByRole('button', { name: '创建' }).click()
    await this.page.waitForTimeout(1_500)
  }

  /** Disable user in the table by username. */
  async disableUser(username: string) {
    const rows = await this.page.locator('tr').all()
    for (const row of rows) {
      const text = await row.innerText().catch(() => '')
      if (text.includes(username)) {
        const toggleBtn = row.getByRole('button', { name: '禁用' })
        if (await toggleBtn.isVisible({ timeout: 2_000 }).catch(() => false)) {
          await toggleBtn.click()
          const confirmBtn = this.page.locator('.el-message-box').getByRole('button', { name: '确认' })
          if (await confirmBtn.isVisible({ timeout: 2_000 }).catch(() => false)) {
            await confirmBtn.click()
          }
        }
        break
      }
    }
    await this.page.waitForTimeout(1_500)
  }

  /** Open edit dialog for a user by username and save changes. */
  async editUser(username: string, opts: { password?: string; isAdmin?: number }) {
    const rows = await this.page.locator('tr').all()
    for (const row of rows) {
      const text = await row.innerText().catch(() => '')
      if (text.includes(username)) {
        await row.getByRole('button', { name: '\u7f16\u8f91' }).click()
        await this.page.waitForSelector('.el-dialog__body', { timeout: 4_000 })
        if (opts.password !== undefined) {
          await this.page.locator('.el-dialog [type="password"]').fill(opts.password)
        }
        if (opts.isAdmin !== undefined) {
          const radioLabel = opts.isAdmin === 1 ? '\u7ba1\u7406\u5458' : '\u666e\u901a\u7528\u6237'
          await this.page.locator('.el-dialog').getByText(radioLabel).click()
        }
        await this.page.locator('.el-dialog').getByRole('button', { name: '\u4fdd\u5b58' }).click()
        await this.page.waitForTimeout(1_500)
        break
      }
    }
  }

  /** Delete a user by username (soft delete). */
  async deleteUser(username: string) {
    const rows = await this.page.locator('tr').all()
    for (const row of rows) {
      const text = await row.innerText().catch(() => '')
      if (text.includes(username)) {
        await row.getByRole('button', { name: '\u5220\u9664' }).click()
        await this.page.waitForSelector('.el-message-box', { timeout: 3_000 })
        await this.page.locator('.el-message-box__btns').getByRole('button', { name: '\u5220\u9664' }).click()
        await this.page.waitForTimeout(1_500)
        break
      }
    }
  }

  /** Re-enable a user via API. */
  async enableUserViaApi(username: string): Promise<string> {
    return await this.page.evaluate(async (name) => {
      const token = localStorage.getItem('token') || ''
      const lr = await fetch('/api/user', { headers: { Authorization: 'Bearer ' + token } })
      const ld = await lr.json()
      const list = (ld.data?.list) ?? []
      const user = list.find((u: any) => u.username === name)
      if (!user) return 'user-not-found'
      const ur = await fetch(`/api/user/${user.id}/status`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
        body: JSON.stringify({ status: 1 }),
      })
      const ud = await ur.json()
      return ud.code === 0 ? 'enabled' : 'enable-failed:' + ud.message
    }, username)
  }
}
