import { test, expect } from '../../fixtures/auth'
import { NotebookPage } from '../../pages/NotebookPage'
import { config } from '../../fixtures/config'

test.describe('TC0008 不同镜像开发机创建', () => {
  let nb: NotebookPage

  test.beforeEach(async ({ adminPage }) => {
    nb = new NotebookPage(adminPage)
  })

  test('TC0008b: 清除记录后创建按钮已启用', async () => {
    await nb.cleanup()
    await nb.goto()
    await expect(nb.createButton).toBeEnabled({ timeout: 5_000 })
  })

  test('TC0008c/d: 使用 PyTorch 镜像创建开发机并显示正确', async () => {
    await nb.cleanup()
    await nb.goto()
    // Select last image option (PyTorch)
    await nb.createNotebook(-1)
    await nb.goto()

    const body = await nb.page.evaluate(() => document.body.innerText)
    const hasPyTorch = body.includes('pytorch-cuda121') || body.includes('PyTorch')
    expect(hasPyTorch).toBeTruthy()

    const hasStatus = body.includes('创建中') || body.includes('运行中')
    expect(hasStatus).toBeTruthy()
  })
})
