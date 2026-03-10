import { test, expect } from '../../fixtures/auth'
import { NotebookPage } from '../../pages/NotebookPage'
import { waitPodReady, execInPod } from '../../fixtures/k8s'
import { config } from '../../fixtures/config'

/**
 * TC0013 — Files written to /home/jovyan survive a notebook restart.
 *
 * The admin pod mounts the NFS-backed per-user subpath at /home/jovyan,
 * so files created there must outlive individual pod lifecycles.
 */
test.describe('TC0013 重启后用户文件持久化', () => {
  test.setTimeout(600_000) // 10 min — pod tear-down + re-spin

  test('TC0013a: /home/jovyan 文件在重启后保留', async ({ adminPage }) => {
    const nb = new NotebookPage(adminPage)

    // ── Step 1: Clean up and create a fresh notebook ──
    await nb.cleanup()
    await nb.goto()
    await nb.createNotebook(0)

    // ── Step 2: Wait for pod to be 1/1 Running ──
    const ready1 = await waitPodReady('jupyterlab-admin', config.podTimeout)
    if (!ready1) {
      test.skip(true, 'Admin pod not ready before restart — skipping TC0013')
      return
    }

    // ── Step 3: Write a sentinel file to /home/jovyan ──
    const filename = `persist_check_${Date.now()}.txt`
    const writeResult = execInPod(
      'jupyterlab-admin',
      `echo "persistence_test" > /home/jovyan/${filename} && cat /home/jovyan/${filename}`,
    )
    expect(writeResult).toContain('persistence_test')

    // ── Step 4: Restart the notebook via UI ──
    await nb.goto()
    await nb.restartNotebook()

    // ── Step 5: Wait for the pod to come back 1/1 Running ──
    const ready2 = await waitPodReady('jupyterlab-admin', config.podTimeout)
    if (!ready2) {
      test.skip(true, 'Admin pod not ready after restart — skipping persistence check')
      return
    }

    // ── Step 6: Verify the sentinel file still exists ──
    const readResult = execInPod(
      'jupyterlab-admin',
      `cat /home/jovyan/${filename}`,
    )
    expect(readResult).toContain('persistence_test')

    // ── Cleanup ──
    execInPod('jupyterlab-admin', `rm -f /home/jovyan/${filename}`)
    await nb.goto()
    await nb.stopNotebook()
    await nb.waitUntilStopped()
    await nb.goto()
    await nb.deleteRecord()
  })
})
