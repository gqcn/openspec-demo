import { type Page, type Locator } from '@playwright/test'

/**
 * SpecPage — /specs (规格管理)
 */
export class SpecPage {
  readonly page: Page
  readonly addButton: Locator
  readonly nameInput: Locator
  readonly cpuInput: Locator
  readonly memoryInput: Locator
  readonly saveButton: Locator

  constructor(page: Page) {
    this.page = page
    this.addButton = page.getByRole('button', { name: '新增规格' })
    this.nameInput = page.getByPlaceholder('如: 4C8G')
    this.cpuInput = page.getByPlaceholder('如: 4', { exact: true })
    this.memoryInput = page.getByPlaceholder('如: 8Gi')
    this.saveButton = page.getByRole('button', { name: '保存' })
  }

  async goto() {
    await this.page.goto('/specs')
    await this.page.waitForLoadState('networkidle')
  }

  /** Create a new spec. */
  async createSpec(name: string, cpu: string, memory: string) {
    await this.addButton.click()
    await this.page.waitForSelector('.el-dialog__body', { timeout: 4_000 })
    await this.nameInput.fill(name)
    await this.cpuInput.fill(cpu)
    await this.memoryInput.fill(memory)
    await this.saveButton.click()
    await this.page.waitForTimeout(1_500)
  }

  /** Edit the spec row matching `targetName`, change CPU. */
  async editSpecCpu(targetName: string, newCpu: string) {
    const rows = await this.page.locator('tr').all()
    for (const row of rows) {
      const text = await row.innerText().catch(() => '')
      if (text.includes(targetName)) {
        await row.getByRole('button', { name: '编辑' }).click()
        break
      }
    }
    await this.page.waitForSelector('.el-dialog__body', { timeout: 3_000 })
    await this.cpuInput.clear()
    await this.cpuInput.fill(newCpu)
    await this.saveButton.click()
    await this.page.waitForTimeout(1_500)
  }

  /** Seed GPU-标准 spec if missing (via API in browser context). */
  async ensureGpuSpec() {
    const result = await this.page.evaluate(async () => {
      const token = localStorage.getItem('token') || ''
      const lr = await fetch('/api/spec', { headers: { Authorization: 'Bearer ' + token } })
      const ld = await lr.json()
      const list = (ld.data?.list) ?? []
      if (list.some((s: any) => s.name === 'GPU-标准')) return 'exists'
      const cr = await fetch('/api/spec', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
        body: JSON.stringify({
          name: 'GPU-标准', cpu: '4', memory: '16Gi', gpu: '1',
          gpuType: 'nvidia.com/gpu',
          nodeSelector: '{"gpu-type": "gpu"}',
          tolerations: '[{"key":"gpu","operator":"Exists","effect":"NoSchedule"}]',
          sortOrder: 30, enabled: 1,
        }),
      })
      const cd = await cr.json()
      return cd.code === 0 ? 'seeded' : 'seed-failed:' + cd.message
    })
    return result
  }
}
