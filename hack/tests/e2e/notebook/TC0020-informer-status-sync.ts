import { test, expect } from '../../fixtures/auth'
import { NotebookPage } from '../../pages/NotebookPage'
import { config } from '../../fixtures/config'
import { kubectl, waitPodReady } from '../../fixtures/k8s'

/**
 * TC0020 — K8S Informer 实时同步 Pod 状态到 DB
 *
 * 验证后端的 K8S Informer 机制能够实时监听 Pod 状态变化并自动更新数据库,
 * 确保前端显示的状态与 K8S 实际状态保持一致。
 *
 * 测试策略:
 *   1. 创建开发机并等待 Pod Running
 *   2. 手动删除 K8S Pod (模拟 Pod 崩溃)
 *   3. 验证 DB 状态在短时间内(10秒)自动更新为 failed
 *   4. 验证前端列表显示状态为"异常"
 */
test.describe('TC0020 Informer 实时同步 Pod 状态', () => {
  let nb: NotebookPage
  const podName = `jupyterlab-${config.adminUser}`

  test.beforeEach(async ({ adminPage }) => {
    nb = new NotebookPage(adminPage)
    // Ensure clean state
    await nb.cleanup()
  })

  test('TC0020a: Pod 被删除后 DB 状态自动更新为 failed', async ({ adminPage }) => {
    // Step 1: Create notebook and wait for Pod to be Running
    await nb.goto()
    await nb.createNotebook(0)

    // Wait for pod to be Running
    await waitPodReady(podName, config.podTimeout)

    // Verify initial status is 'running' in DB
    await nb.goto()
    const initialStatus = await nb.getNotebookStatus()
    expect(initialStatus, 'Initial status should be running').toBe('running')

    // Step 2: Manually delete the K8S Pod (simulate pod crash)
    kubectl(`delete pod ${podName} --grace-period=0 --force`)

    // Step 3: Wait for Informer to detect the deletion and update DB
    // The Informer should update the status to 'failed' within seconds
    await adminPage.waitForTimeout(10_000)

    // Step 4: Verify DB status is now 'failed'
    const updatedStatus = await adminPage.evaluate(async () => {
      const token = localStorage.getItem('token') || ''
      const r = await fetch('/api/notebook', {
        headers: { Authorization: 'Bearer ' + token },
      })
      const d = await r.json()
      const list: Array<{ status: string }> = d.data?.list ?? []
      return list[0]?.status ?? ''
    })

    expect(updatedStatus, 'Status should be updated to failed by Informer').toBe('failed')
  })

  test('TC0020b: 前端列表显示 Informer 同步后的状态', async () => {
    // Step 1: Create notebook and wait for Pod to be Running
    await nb.goto()
    await nb.createNotebook(0)
    await waitPodReady(podName, config.podTimeout)

    // Step 2: Manually delete the K8S Pod
    kubectl(`delete pod ${podName} --grace-period=0 --force`)

    // Step 3: Wait for Informer to sync
    await nb.page.waitForTimeout(10_000)

    // Step 4: Refresh page and verify frontend displays "异常" status
    await nb.goto()

    // The status badge should show "异常" (failed)
    const statusBadge = nb.page.locator('.ant-badge-status-text').first()
    await expect(statusBadge).toContainText('异常', { timeout: 5_000 })
  })

  test.afterEach(async () => {
    // Clean up any remaining resources
    await nb.cleanup()
  })
})
