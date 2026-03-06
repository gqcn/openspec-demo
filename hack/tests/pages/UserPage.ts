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
          const confirmBtn = this.page.getByRole('button', { name: '确定' })
          if (await confirmBtn.isVisible({ timeout: 2_000 }).catch(() => false)) {
            await confirmBtn.click()
          }
        }
        break
      }
    }
    await this.page.waitForTimeout(1_500)
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
