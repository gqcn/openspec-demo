import { type Page, type Locator } from '@playwright/test'

/**
 * LoginPage — /login
 */
export class LoginPage {
  readonly page: Page
  readonly usernameInput: Locator
  readonly passwordInput: Locator
  readonly loginButton: Locator
  readonly errorMessage: Locator

  constructor(page: Page) {
    this.page = page
    this.usernameInput = page.getByPlaceholder('请输入用户名')
    this.passwordInput = page.getByPlaceholder('请输入密码')
    this.loginButton = page.getByRole('button', { name: 'login' })
    this.errorMessage = page.locator('.el-message--error')
  }

  async goto() {
    await this.page.goto('/auth/login')
  }

  async login(username: string, password: string) {
    await this.usernameInput.fill(username)
    await this.passwordInput.fill(password)
    await this.loginButton.click()
  }

  async loginAndWaitForRedirect(username: string, password: string) {
    await this.login(username, password)
    await this.page.waitForURL('**/notebooks', { timeout: 8_000 })
  }
}
