import { type Page } from '@playwright/test'

/**
 * JupyterLabPage — JupyterLab UI (opened in new tab after clicking '进入')
 */
export class JupyterLabPage {
  readonly page: Page

  constructor(page: Page) {
    this.page = page
  }

  /** Wait for JupyterLab DOM to be ready (jp-* elements). */
  async waitForReady(timeoutMs = 40_000) {
    const deadline = Date.now() + timeoutMs
    while (Date.now() < deadline) {
      const count = await this.page.locator('[class^="jp-"]').count()
      if (count > 5) return true
      await this.page.waitForTimeout(1_000)
    }
    return false
  }

  /** Check file browser panel is visible. */
  async hasFileBrowser(): Promise<boolean> {
    const count = await this.page.locator('.jp-FileBrowser, .jp-BreadCrumbs, .jp-DirListing').count()
    return count > 0
  }

  /** Open a new Python 3 notebook from launcher, or reuse existing one. */
  async openPythonNotebook() {
    // Check if a notebook tab is already open (from previous test)
    const existingNotebook = this.page.locator('.jp-Notebook').first()
    if ((await existingNotebook.count()) > 0 && await existingNotebook.isVisible().catch(() => false)) {
      // Already have a notebook open — use it
      return
    }

    // Click the launcher's Python 3 card (has jp-LauncherCard class)
    const launcherCard = this.page.locator('.jp-LauncherCard [title*="Python 3"], .jp-Launcher-item [title*="Python 3"]').first()
    if ((await launcherCard.count()) > 0) {
      await launcherCard.click({ timeout: 10_000 })
    } else {
      // Fallback: try text-based match within launcher area
      await this.page.locator('.jp-Launcher').getByText('Python 3 (ipykernel)').first().click({ timeout: 10_000 })
    }
    await this.page.waitForTimeout(3_000)
  }

  /** Type code into the first cell and run with Shift+Enter. */
  async runCode(code: string) {
    const cell = this.page.locator('.jp-Cell .jp-InputArea-editor .CodeMirror-code, .jp-Cell .cm-content').first()
    await cell.click()
    await this.page.keyboard.insertText(code)
    await this.page.waitForTimeout(500)
    await cell.click().catch(() => {})
    await this.page.keyboard.press('Shift+Enter')
    await this.page.waitForTimeout(10_000)
  }

  /** Wait for specific text to appear on the page. */
  async waitForOutput(text: string, timeoutMs = 60_000): Promise<boolean> {
    const deadline = Date.now() + timeoutMs
    while (Date.now() < deadline) {
      const body = await this.page.evaluate(() => document.body.innerText)
      if (body.includes(text)) return true
      await this.page.waitForTimeout(1_000)
    }
    return false
  }

  /** Check if output cells contain error output. */
  async hasErrors(): Promise<boolean> {
    // Check for red-styled error outputs (jp-OutputArea-child with error class)
    const errorOutputs = await this.page.locator('.jp-RenderedText[data-mime-type="application/vnd.jupyter.stderr"]').count()
    if (errorOutputs > 0) return true
    // Also check for Python tracebacks in output text
    const outputs = await this.page.locator('.jp-OutputArea-output').allTextContents()
    const text = outputs.join('\n')
    return text.includes('Traceback (most recent call last)')
  }
}
