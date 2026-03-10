import { test, expect } from '../../fixtures/auth'
import { SpecPage } from '../../pages/SpecPage'
import { UserPage } from '../../pages/UserPage'

test.describe('TC-16 分页组件与字段完整性', () => {
  test('TC-16a: 规格管理列表包含分页组件', async ({ adminPage }) => {
    const specPage = new SpecPage(adminPage)
    await specPage.goto()
    await expect(adminPage.locator('.el-pagination')).toBeVisible({ timeout: 5_000 })
  })

  test('TC-16b: 用户管理列表包含分页组件', async ({ adminPage }) => {
    const userPage = new UserPage(adminPage)
    await userPage.goto()
    await expect(adminPage.locator('.el-pagination')).toBeVisible({ timeout: 5_000 })
  })

  test('TC-16c: 规格管理列表创建时间列有数据', async ({ adminPage }) => {
    const specPage = new SpecPage(adminPage)
    await specPage.goto()
    // Find any data row that has a createdAt value matching date pattern
    const rows = adminPage.locator('.el-table__body tr')
    const firstRow = rows.first()
    await expect(firstRow).toBeVisible({ timeout: 5_000 })
    // createdAt is column index 7 (ID=0, name=1, cpu=2, memory=3, gpu=4, gpuType=5, status=6, createdAt=7)
    const createdAtCell = firstRow.locator('td').nth(7)
    const text = await createdAtCell.innerText()
    expect(text.trim()).toMatch(/\d{4}-\d{2}-\d{2}/)
  })

  test('TC-16d: 规格列表 API 返回 total 字段', async ({ adminPage }) => {
    const result = await adminPage.evaluate(async () => {
      const token = localStorage.getItem('token') || ''
      const r = await fetch('/api/spec?page=1&size=20', {
        headers: { Authorization: 'Bearer ' + token },
      })
      const d = await r.json()
      return { code: d.code, total: d.data?.total, listLen: d.data?.list?.length ?? 0 }
    })
    expect(result.code).toBe(0)
    expect(result.total).toBeGreaterThanOrEqual(1)
    expect(result.listLen).toBeGreaterThanOrEqual(1)
  })

  test('TC-16e: 用户列表 API 返回 total 字段且分页生效', async ({ adminPage }) => {
    const result = await adminPage.evaluate(async () => {
      const token = localStorage.getItem('token') || ''
      const r = await fetch('/api/user?page=1&size=1', {
        headers: { Authorization: 'Bearer ' + token },
      })
      const d = await r.json()
      return { code: d.code, total: d.data?.total, listLen: d.data?.list?.length ?? 0 }
    })
    expect(result.code).toBe(0)
    // total should be >= 1 (admin always exists)
    expect(result.total).toBeGreaterThanOrEqual(1)
    // With size=1, we should get exactly 1 item
    expect(result.listLen).toBe(1)
  })
})
