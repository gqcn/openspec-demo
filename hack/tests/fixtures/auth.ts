import { test as base, type Page } from '@playwright/test'
import { LoginPage } from '../pages/LoginPage'
import { MainLayout } from '../pages/MainLayout'
import { config } from './config'

export type AuthFixtures = {
  /** A page that is already logged in as admin. */
  adminPage: Page
  loginPage: LoginPage
  mainLayout: MainLayout
}

/**
 * Auth fixture — logs in as admin before each test, available as `adminPage`.
 * Also exposes `loginPage` and `mainLayout` for direct use.
 */
export const test = base.extend<AuthFixtures>({
  loginPage: async ({ page }, use) => {
    await use(new LoginPage(page))
  },
  mainLayout: async ({ page }, use) => {
    await use(new MainLayout(page))
  },
  adminPage: async ({ page }, use) => {
    const loginPage = new LoginPage(page)
    await loginPage.goto()
    await loginPage.loginAndWaitForRedirect(config.adminUser, config.adminPass)
    await use(page)
  },
})

export { expect } from '@playwright/test'
