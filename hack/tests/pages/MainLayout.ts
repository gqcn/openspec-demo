import { type Page, type Locator } from '@playwright/test'

/**
 * MainLayout — shared header/sidebar present on all authenticated pages.
 */
export class MainLayout {
  readonly page: Page
  readonly sidebar: Locator

  constructor(page: Page) {
    this.page = page
    this.sidebar = page.locator('.el-aside, .el-menu')
  }

  /** Hover the user dropdown in header and logout. */
  async logout(displayName: string) {
    // Element Plus el-dropdown uses hover trigger by default
    const trigger = this.page.locator('.el-header .el-dropdown').first()
    await trigger.hover({ timeout: 5_000 })
    const menuItem = this.page.getByRole('menuitem', { name: '退出登录' })
    await menuItem.waitFor({ state: 'visible', timeout: 5_000 })
    await menuItem.click()
    await this.page.waitForURL('**/login', { timeout: 8_000 }).catch(() => {})
  }
}
