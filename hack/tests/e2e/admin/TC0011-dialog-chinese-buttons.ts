import { test, expect } from '../../fixtures/auth'
import { SpecPage } from '../../pages/SpecPage'

test.describe('TC0011 对话框按钮中文化', () => {
  test('TC0011a: 规格管理禁用确认对话框按钮为中文', async ({ adminPage }) => {
    const specPage = new SpecPage(adminPage)
    await specPage.goto()

    // Click the first 禁用 button to trigger ElMessageBox.confirm
    const disableBtn = adminPage.getByRole('button', { name: '禁用' }).first()
    if (await disableBtn.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await disableBtn.click()
      // Wait for the confirm dialog to appear
      const dialog = adminPage.locator('.el-message-box')
      await dialog.waitFor({ state: 'visible', timeout: 5_000 })

      // Verify buttons are in Chinese — should NOT have "Cancel" or "OK"
      const dialogText = await dialog.innerText()
      expect(dialogText).not.toContain('Cancel')
      expect(dialogText).not.toContain('OK')

      // Should have Chinese button text (确定 or 取消)
      const cancelBtn = dialog.locator('.el-message-box__btns button').first()
      const cancelText = await cancelBtn.innerText()
      expect(cancelText).toContain('取消')

      // Close the dialog
      await cancelBtn.click()
    }
  })

  test('TC0011b: 规格管理删除确认对话框按钮为中文', async ({ adminPage }) => {
    const specPage = new SpecPage(adminPage)
    await specPage.goto()

    // Click the first 删除 button to trigger ElMessageBox.confirm
    const deleteBtn = adminPage.getByRole('button', { name: '删除' }).first()
    if (await deleteBtn.isVisible({ timeout: 3_000 }).catch(() => false)) {
      await deleteBtn.click()
      const dialog = adminPage.locator('.el-message-box')
      await dialog.waitFor({ state: 'visible', timeout: 5_000 })

      const dialogText = await dialog.innerText()
      expect(dialogText).not.toContain('Cancel')
      expect(dialogText).not.toContain('OK')

      // Close the dialog
      const cancelBtn = dialog.locator('.el-message-box__btns button').first()
      await cancelBtn.click()
    }
  })
})
