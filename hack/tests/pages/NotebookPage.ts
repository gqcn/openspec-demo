import { type Page, type Locator } from '@playwright/test'

/**
 * NotebookPage — /notebooks
 *
 * Handles notebook list, create dialog, stop/delete actions.
 */
export class NotebookPage {
  readonly page: Page
  readonly createButton: Locator
  readonly stopButton: Locator
  readonly enterButton: Locator
  readonly deleteRecordButton: Locator

  constructor(page: Page) {
    this.page = page
    this.createButton = page.getByRole('button', { name: '创建开发机' })
    this.stopButton = page.getByRole('button', { name: '停止' }).first()
    this.enterButton = page.getByRole('button', { name: '进入' })
    this.deleteRecordButton = page.getByRole('button', { name: '删除记录' }).first()
  }

  async goto() {
    await this.page.goto('/notebooks')
    await this.page.waitForLoadState('networkidle')
  }

  /** Open create dialog, select spec + image, confirm. */
  async createNotebook(imageIndex = 0) {
    await this.createButton.click()
    await this.page.waitForSelector('.spec-card', { timeout: 5_000 })
    await this.page.waitForTimeout(300)
    // Select first spec
    await this.page.locator('.spec-card').first().click()
    // Open image dropdown
    await this.page.locator('.el-select__wrapper').first().click()
    await this.page.waitForSelector('[role="option"]', { timeout: 3_000 })
    const opts = await this.page.locator('[role="option"]').all()
    const idx = imageIndex < 0 ? opts.length - 1 : Math.min(imageIndex, opts.length - 1)
    await opts[idx].click()
    // Confirm
    await this.page.getByRole('button', { name: '创建', exact: true }).click()
    await this.page.waitForTimeout(2_000)
  }

  /** Stop the first active notebook and confirm dialog. */
  async stopNotebook() {
    await this.stopButton.click()
    const msgBox = this.page.locator('.el-message-box')
    await msgBox.waitFor({ state: 'visible', timeout: 3_000 })
    await msgBox.getByRole('button', { name: '停止', exact: true }).click()
    await this.page.waitForTimeout(3_000)
  }

  /** Delete stopped/failed notebook record. */
  async deleteRecord() {
    await this.deleteRecordButton.click()
    const confirmBtn = this.page.getByRole('button', { name: '删除', exact: true })
    if (await confirmBtn.isVisible({ timeout: 2_000 }).catch(() => false)) {
      await confirmBtn.click()
    }
    await this.page.waitForTimeout(1_500)
  }

  /** Full cleanup: stop active + delete record. */
  async cleanup() {
    await this.goto()
    if (await this.hasActiveNotebook()) {
      await this.stopNotebook()
      await this.waitUntilStopped()
    }
    await this.goto()
    if (await this.hasStoppedNotebook()) {
      await this.deleteRecord()
    }
  }

  async hasActiveNotebook(): Promise<boolean> {
    const body = await this.page.evaluate(() => document.body.innerText)
    return body.includes('运行中') || body.includes('创建中') || body.includes('停止中')
  }

  async hasStoppedNotebook(): Promise<boolean> {
    const body = await this.page.evaluate(() => document.body.innerText)
    return body.includes('已停止') || body.includes('异常')
  }

  /** Poll until no active notebook (max ~60s). */
  async waitUntilStopped(maxIterations = 12) {
    for (let i = 0; i < maxIterations; i++) {
      await this.goto()
      if (!(await this.hasActiveNotebook())) return
      await this.page.waitForTimeout(3_000)
    }
  }

  /** Check if the body contains certain text. */
  async bodyContains(text: string): Promise<boolean> {
    const body = await this.page.evaluate(() => document.body.innerText)
    return body.includes(text)
  }
}
