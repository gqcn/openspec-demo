import { test, expect } from '../../fixtures/auth'
import { SpecPage } from '../../pages/SpecPage'

test.describe('TC-2 规格管理', () => {
  let specPage: SpecPage

  test.beforeEach(async ({ adminPage }) => {
    specPage = new SpecPage(adminPage)
  })

  test('TC-2 seed: 确保 GPU-标准 规格存在', async () => {
    await specPage.goto()
    const result = await specPage.ensureGpuSpec()
    expect(['exists', 'seeded']).toContain(result)
  })

  test('TC-2a: 页面标题为规格管理', async () => {
    await specPage.goto()
    await expect(specPage.page.getByRole('heading', { name: '规格管理' })).toBeVisible()
  })

  test('TC-2b: 包含 CPU-小 规格', async () => {
    await specPage.goto()
    await expect(specPage.page.getByText('CPU-小')).toBeVisible()
  })

  test('TC-2c: 包含 CPU-大 规格', async () => {
    await specPage.goto()
    await expect(specPage.page.getByText('CPU-大')).toBeVisible()
  })

  test('TC-2d: 包含 GPU-标准 规格', async () => {
    await specPage.goto()
    await expect(specPage.page.getByText('GPU-标准', { exact: true })).toBeVisible()
  })

  test('TC-2e: 包含编辑操作', async () => {
    await specPage.goto()
    await expect(specPage.page.getByText('编辑').first()).toBeVisible()
  })

  test('TC-2f: 创建规格后出现在列表', async () => {
    await specPage.goto()
    await specPage.createSpec('Test-CPU-E2E', '500m', '1Gi')
    await specPage.goto()
    await expect(specPage.page.getByText('Test-CPU-E2E').first()).toBeVisible()
  })

  test('TC-2g: 修改规格 CPU 后更新成功', async () => {
    await specPage.goto()
    await specPage.editSpecCpu('Test-CPU-E2E', '1000m')
    await specPage.goto()
    await expect(specPage.page.getByText('1000m')).toBeVisible()
  })
})
