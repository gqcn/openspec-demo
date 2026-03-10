import { test, expect } from '../../fixtures/auth'
import { SpecPage } from '../../pages/SpecPage'

test.describe('TC0002 规格管理', () => {
  let specPage: SpecPage

  test.beforeEach(async ({ adminPage }) => {
    specPage = new SpecPage(adminPage)
  })

  test('TC0002 seed: 确保 GPU-标准 规格存在', async () => {
    await specPage.goto()
    const result = await specPage.ensureGpuSpec()
    expect(['exists', 'seeded']).toContain(result)
  })

  test('TC0002a: 页面标题为规格管理', async () => {
    await specPage.goto()
    await expect(specPage.page.getByRole('heading', { name: '规格管理' })).toBeVisible()
  })

  test('TC0002b: 包含 CPU-小 规格', async () => {
    await specPage.goto()
    // With pagination, seed specs may not appear on page 1. Verify via API.
    const found = await specPage.page.evaluate(async () => {
      const token = localStorage.getItem('token') || ''
      const r = await fetch('/api/spec?page=1&size=1000', { headers: { Authorization: 'Bearer ' + token } })
      const d = await r.json()
      return (d.data?.list ?? []).some((s: any) => s.name === 'CPU-小')
    })
    expect(found).toBe(true)
  })

  test('TC0002c: 包含 CPU-大 规格', async () => {
    await specPage.goto()
    const found = await specPage.page.evaluate(async () => {
      const token = localStorage.getItem('token') || ''
      const r = await fetch('/api/spec?page=1&size=1000', { headers: { Authorization: 'Bearer ' + token } })
      const d = await r.json()
      return (d.data?.list ?? []).some((s: any) => s.name === 'CPU-大')
    })
    expect(found).toBe(true)
  })

  test('TC0002d: 包含 GPU-标准 规格', async () => {
    await specPage.goto()
    const found = await specPage.page.evaluate(async () => {
      const token = localStorage.getItem('token') || ''
      const r = await fetch('/api/spec?page=1&size=1000', { headers: { Authorization: 'Bearer ' + token } })
      const d = await r.json()
      return (d.data?.list ?? []).some((s: any) => s.name === 'GPU-标准')
    })
    expect(found).toBe(true)
  })

  test('TC0002e: 包含编辑操作', async () => {
    await specPage.goto()
    await expect(specPage.page.getByText('编辑').first()).toBeVisible()
  })

  test('TC0002f: 创建规格后出现在列表', async () => {
    await specPage.goto()
    await specPage.createSpec('Test-CPU-E2E', '500m', '1Gi')
    await specPage.goto()
    await expect(specPage.page.getByText('Test-CPU-E2E').first()).toBeVisible()
  })

  test('TC0002g: 修改规格 CPU 后更新成功', async () => {
    await specPage.goto()
    await specPage.editSpecCpu('Test-CPU-E2E', '1000m')
    await specPage.goto()
    const rows = specPage.page.locator('tr')
    const targetRow = rows.filter({ hasText: 'Test-CPU-E2E' }).first()
    await expect(targetRow.getByText('1000m')).toBeVisible()
  })
})
