import { test, expect } from '../../fixtures/auth'
import { NotebookPage } from '../../pages/NotebookPage'
import { config } from '../../fixtures/config'

test.describe('TC0004 创建开发机', () => {
  let nb: NotebookPage

  test.beforeEach(async ({ adminPage }) => {
    nb = new NotebookPage(adminPage)
  })

  test('TC0004a/b: 创建开发机后记录存在且状态为创建中或运行中', async () => {
    await nb.goto()
    // Stop any existing running instance first
    if (await nb.hasActiveNotebook()) {
      await nb.stopNotebook()
      await nb.waitUntilStopped()
      await nb.goto()
      if (await nb.hasStoppedNotebook()) {
        await nb.deleteRecord()
      }
    }

    await nb.goto()
    await nb.createNotebook(0)
    await nb.goto()

    // Wait for the record to appear
    await expect(nb.page.getByRole('main').getByText('admin')).toBeVisible({ timeout: 10_000 })

    const body = await nb.page.evaluate(() => document.body.innerText)
    const hasValidStatus = body.includes('运行中') || body.includes('创建中')
    expect(hasValidStatus).toBeTruthy()
  })

  test('TC0004c: 有活跃实例时创建按钮已禁用', async () => {
    await nb.goto()
    await expect(nb.createButton).toBeDisabled({ timeout: 5_000 })
  })

  test('TC0004d: API 拒绝重复创建开发机', async () => {
    await nb.goto()
    const code = await nb.page.evaluate(async () => {
      const token = localStorage.getItem('token') || ''
      const r = await fetch('/api/notebook', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
        body: JSON.stringify({ specId: 1, imageKey: 'python-general' }),
      })
      const d = await r.json()
      return d.code
    })
    expect(code).not.toBe(0)
  })
})
