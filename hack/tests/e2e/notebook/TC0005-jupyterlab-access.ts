import { test, expect } from '../../fixtures/auth'
import { NotebookPage } from '../../pages/NotebookPage'
import { JupyterLabPage } from '../../pages/JupyterLabPage'
import { waitPodReady } from '../../fixtures/k8s'
import { config } from '../../fixtures/config'

test.describe('TC0005 JupyterLab 访问', () => {
  test.setTimeout(300_000)  // 5 min — pod startup can be slow

  test('TC0005a~d: Pod 就绪后可访问 JupyterLab', async ({ adminPage, context }) => {
    const nb = new NotebookPage(adminPage)

    // Always ensure a clean notebook with default image (index 0)
    // Previous tests (TC0008) may leave a notebook with an un-pullable image
    await nb.cleanup()
    await nb.goto()
    await nb.createNotebook(0)

    // TC0005a: Wait for pod
    const podReady = await waitPodReady('jupyterlab-admin', config.podTimeout)
    expect(podReady).toBeTruthy()

    // TC0005b: Status shows 运行中
    await nb.goto()
    await expect(nb.page.getByText('运行中')).toBeVisible({ timeout: 10_000 })

    // Open JupyterLab — click '进入' which opens a new tab
    const [jupyterTab] = await Promise.all([
      context.waitForEvent('page', { timeout: 15_000 }),
      nb.enterButton.click(),
    ])
    await jupyterTab.waitForLoadState('domcontentloaded')

    const jupyter = new JupyterLabPage(jupyterTab)

    // TC0005c: JupyterLab UI loaded
    const loaded = await jupyter.waitForReady(40_000)
    expect(loaded).toBeTruthy()

    // TC0005d: File browser visible
    const hasFB = await jupyter.hasFileBrowser()
    expect(hasFB).toBeTruthy()

    await jupyterTab.close()
  })
})
