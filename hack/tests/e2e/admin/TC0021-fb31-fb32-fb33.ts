import { type Page } from '@playwright/test'
import { test, expect } from '../../fixtures/auth'
import { config } from '../../fixtures/config'

/**
 * Extract JWT token from Vben Pinia persisted localStorage.
 * Key has versioned prefix like `ai-training-platform-X.Y.Z-dev-core-access`.
 */
async function getToken(page: Page): Promise<string> {
  return await page.evaluate(() => {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i) || ''
      if (key.endsWith('-core-access')) {
        try {
          const v = JSON.parse(localStorage.getItem(key) || '{}')
          if (v.accessToken) return v.accessToken as string
        } catch { /* ignore */ }
      }
    }
    return localStorage.getItem('token') || ''
  })
}

test.describe('TC0021 FB-31/32/33 反馈修复验证', () => {

  // ─── FB-31: 重复用户名时只弹出 1 条错误提示 ─────────────────
  test('TC0021a: 创建重复用户名时只弹出 1 条错误提示', async ({ adminPage }) => {
    await adminPage.goto('/users')
    await adminPage.waitForLoadState('networkidle')

    // 通过 UI 操作验证：打开新增抽屉，填入已存在用户名，提交
    await adminPage.getByRole('button', { name: '新增用户' }).click()
    await adminPage.waitForTimeout(800)

    // 填写表单
    await adminPage.getByLabel('用户名').first().fill('admin')
    await adminPage.getByLabel('密码').first().fill('Test@123456')
    // 选择角色
    const roleSelect = adminPage.locator('.ant-select').first()
    if (await roleSelect.isVisible({ timeout: 2_000 }).catch(() => false)) {
      await roleSelect.click()
      await adminPage.waitForTimeout(300)
      await adminPage.getByTitle('普通用户').first().click()
      await adminPage.waitForTimeout(300)
    }

    // 点击确认提交
    const confirmBtn = adminPage.getByRole('button', { name: /确\s*认/ }).last()
    await confirmBtn.click()
    await adminPage.waitForTimeout(2_000)

    // 检查 ant-message 错误提示数量：应该只有 1 条
    const errorMessages = adminPage.locator('.ant-message-error, .ant-message-notice-error')
    const count = await errorMessages.count()
    // 最多 1 条错误提示（拦截器统一处理）
    expect(count).toBeLessThanOrEqual(1)
  })

  // ─── FB-32: 当前用户行不显示禁用和删除按钮 ─────────────────
  test('TC0021b: admin 用户行不显示禁用按钮', async ({ adminPage }) => {
    await adminPage.goto('/users')
    await adminPage.waitForLoadState('networkidle')

    const adminRow = adminPage.locator('tr').filter({ hasText: config.adminUser }).first()
    await expect(adminRow).toBeVisible({ timeout: 5_000 })

    const disableBtn = adminRow.getByRole('button', { name: '禁用' })
    await expect(disableBtn).not.toBeVisible()
  })

  test('TC0021c: admin 用户行不显示删除按钮', async ({ adminPage }) => {
    await adminPage.goto('/users')
    await adminPage.waitForLoadState('networkidle')

    const adminRow = adminPage.locator('tr').filter({ hasText: config.adminUser }).first()
    await expect(adminRow).toBeVisible({ timeout: 5_000 })

    const deleteBtn = adminRow.getByRole('button', { name: '删除' })
    await expect(deleteBtn).not.toBeVisible()
  })

  test('TC0021d: 后端拒绝禁用自己', async ({ adminPage }) => {
    await adminPage.goto('/users')
    await adminPage.waitForLoadState('networkidle')

    const token = await getToken(adminPage)
    expect(token).toBeTruthy()

    const result = await adminPage.evaluate(async (t) => {
      const lr = await fetch('/api/user?page=1&size=100', { headers: { Authorization: 'Bearer ' + t } })
      const ld = await lr.json()
      const adminUser = (ld.data?.list ?? []).find((u: any) => u.username === 'admin')
      if (!adminUser) return { code: -1, error: 'admin-not-found' }

      const dr = await fetch(`/api/user/${adminUser.id}/status`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
        body: JSON.stringify({ status: 0 }),
      })
      const dd = await dr.json()
      return { code: dd.code, message: dd.message }
    }, token)
    // 应该返回业务错误码，而非 0（成功）
    expect(result.code).not.toBe(0)
  })

  test('TC0021e: 后端拒绝删除自己', async ({ adminPage }) => {
    await adminPage.goto('/users')
    await adminPage.waitForLoadState('networkidle')

    const token = await getToken(adminPage)
    expect(token).toBeTruthy()

    const result = await adminPage.evaluate(async (t) => {
      const lr = await fetch('/api/user?page=1&size=100', { headers: { Authorization: 'Bearer ' + t } })
      const ld = await lr.json()
      const adminUser = (ld.data?.list ?? []).find((u: any) => u.username === 'admin')
      if (!adminUser) return { code: -1, error: 'admin-not-found' }

      const dr = await fetch(`/api/user/${adminUser.id}`, {
        method: 'DELETE',
        headers: { Authorization: 'Bearer ' + t },
      })
      const dd = await dr.json()
      return { code: dd.code, message: dd.message }
    }, token)
    expect(result.code).not.toBe(0)
  })

  // ─── FB-33: 规格表格列标题带单位 ─────────────────────────────
  test('TC0021f: 规格列表 CPU 列标题显示 CPU (Cores)', async ({ adminPage }) => {
    await adminPage.goto('/specs')
    await adminPage.waitForLoadState('networkidle')

    const cpuHeader = adminPage.locator('.vxe-header--column').filter({ hasText: 'CPU (Cores)' }).first()
    await expect(cpuHeader).toBeVisible({ timeout: 5_000 })
  })

  test('TC0021g: 规格列表内存列标题显示 内存 (Gi)', async ({ adminPage }) => {
    await adminPage.goto('/specs')
    await adminPage.waitForLoadState('networkidle')

    const memHeader = adminPage.locator('.vxe-header--column').filter({ hasText: '内存 (Gi)' }).first()
    await expect(memHeader).toBeVisible({ timeout: 5_000 })
  })

  test('TC0021h: 新增规格表单内存字段为数字输入', async ({ adminPage }) => {
    await adminPage.goto('/specs')
    await adminPage.waitForLoadState('networkidle')

    await adminPage.getByRole('button', { name: '新增规格' }).click()
    await adminPage.waitForTimeout(800)

    const memLabel = adminPage.getByText('内存 (Gi)').first()
    await expect(memLabel).toBeVisible({ timeout: 5_000 })

    const memInput = adminPage.locator('.ant-input-number').first()
    await expect(memInput).toBeVisible({ timeout: 3_000 })
  })

  // 非当前用户行应该有禁用和删除按钮
  test('TC0021i: 非当前用户行显示禁用和删除按钮', async ({ adminPage }) => {
    await adminPage.goto('/users')
    await adminPage.waitForLoadState('networkidle')

    const token = await getToken(adminPage)
    expect(token).toBeTruthy()

    const testUser = `tc21i_${Date.now()}`.slice(0, 32)

    // 创建测试用户
    const createResult = await adminPage.evaluate(async ({ username, t }) => {
      const r = await fetch('/api/user', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + t },
        body: JSON.stringify({ username, password: 'Test@123456', isAdmin: 0 }),
      })
      return r.json()
    }, { username: testUser, t: token })
    expect(createResult.code).toBe(0)

    // 获取用户 ID（清理用）
    const userId = await adminPage.evaluate(async ({ username, t }) => {
      const r = await fetch('/api/user?page=1&size=1000', { headers: { Authorization: 'Bearer ' + t } })
      const d = await r.json()
      const user = (d.data?.list ?? []).find((u: any) => u.username === username)
      return user?.id
    }, { username: testUser, t: token })
    expect(userId).toBeTruthy()

    // 刷新页面
    await adminPage.goto('/users')
    await adminPage.waitForLoadState('networkidle')
    await adminPage.waitForTimeout(500)

    // 如果有分页，翻到最后一页
    const lastPageBtn = adminPage.locator('.ant-pagination-item').last()
    if (await lastPageBtn.isVisible({ timeout: 2_000 }).catch(() => false)) {
      await lastPageBtn.click()
      await adminPage.waitForTimeout(1_000)
    }

    const testRow = adminPage.locator('tr').filter({ hasText: testUser }).first()
    await expect(testRow).toBeVisible({ timeout: 5_000 })

    const disableBtn = testRow.getByRole('button', { name: '禁用' })
    await expect(disableBtn).toBeVisible()
    const deleteBtn = testRow.getByRole('button', { name: '删除' })
    await expect(deleteBtn).toBeVisible()

    // 清理
    await adminPage.evaluate(async ({ id, t }) => {
      await fetch(`/api/user/${id}`, {
        method: 'DELETE',
        headers: { Authorization: 'Bearer ' + t },
      })
    }, { id: userId, t: token })
  })
})
