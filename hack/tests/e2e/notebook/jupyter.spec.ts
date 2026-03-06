import { test, expect } from '../../fixtures/auth'
import { NotebookPage } from '../../pages/NotebookPage'
import { JupyterLabPage } from '../../pages/JupyterLabPage'
import { waitPodReady } from '../../fixtures/k8s'
import { config } from '../../fixtures/config'

test.describe('TC-5 JupyterLab 访问', () => {
  test.setTimeout(300_000)  // 5 min — pod startup can be slow

  test('TC-5a~d: Pod 就绪后可访问 JupyterLab', async ({ adminPage, context }) => {
    const nb = new NotebookPage(adminPage)

    // Always ensure a clean notebook with default image (index 0)
    // Previous tests (TC-8) may leave a notebook with an un-pullable image
    await nb.cleanup()
    await nb.goto()
    await nb.createNotebook(0)

    // TC-5a: Wait for pod
    const podReady = await waitPodReady('jupyterlab-admin', config.podTimeout)
    expect(podReady).toBeTruthy()

    // TC-5b: Status shows 运行中
    await nb.goto()
    await expect(nb.page.getByText('运行中')).toBeVisible({ timeout: 10_000 })

    // Open JupyterLab — click '进入' which opens a new tab
    const [jupyterTab] = await Promise.all([
      context.waitForEvent('page', { timeout: 15_000 }),
      nb.enterButton.click(),
    ])
    await jupyterTab.waitForLoadState('domcontentloaded')

    const jupyter = new JupyterLabPage(jupyterTab)

    // TC-5c: JupyterLab UI loaded
    const loaded = await jupyter.waitForReady(40_000)
    expect(loaded).toBeTruthy()

    // TC-5d: File browser visible
    const hasFB = await jupyter.hasFileBrowser()
    expect(hasFB).toBeTruthy()

    await jupyterTab.close()
  })
})

test.describe('TC-6 训练代码执行', () => {
  test.setTimeout(300_000)

  const TRAINING_CODE = `
# Simple gradient descent — linear regression
X = [1.0, 2.0, 3.0, 4.0, 5.0]
y_true = [2.0, 4.0, 6.0, 8.0, 10.0]

w, b = 0.0, 0.0
lr = 0.01
n = len(X)

for epoch in range(2000):
    y_pred = [w * x + b for x in X]
    loss = sum((yp - yt)**2 for yp, yt in zip(y_pred, y_true)) / n
    dw = sum(2*(yp - yt)*x for yp, yt, x in zip(y_pred, y_true, X)) / n
    db = sum(2*(yp - yt) for yp, yt in zip(y_pred, y_true)) / n
    w -= lr * dw
    b -= lr * db

print(f"Trained: w={w:.4f}, b={b:.4f}, loss={loss:.8f}")
assert abs(w - 2.0) < 0.05, f"Expected w~2, got {w:.4f}"
assert abs(b) < 0.2,        f"Expected b~0, got {b:.4f}"
print("TRAINING_TEST_PASSED")
`.trim()

  test('TC-6a~c: JupyterLab 中执行训练代码', async ({ adminPage, context }) => {
    const nb = new NotebookPage(adminPage)
    await nb.goto()

    // Pod must be running
    const podReady = await waitPodReady('jupyterlab-admin', config.podTimeout)
    test.skip(!podReady, 'Pod not ready — skipping training test')

    // Open JupyterLab tab
    const [jupyterTab] = await Promise.all([
      context.waitForEvent('page', { timeout: 15_000 }),
      nb.enterButton.click(),
    ])
    await jupyterTab.waitForLoadState('domcontentloaded')

    const jupyter = new JupyterLabPage(jupyterTab)
    await jupyter.waitForReady(40_000)

    // Open new notebook and run code
    await jupyter.openPythonNotebook()
    await jupyter.runCode(TRAINING_CODE)

    // TC-6a: output contains marker
    const passed = await jupyter.waitForOutput('TRAINING_TEST_PASSED', 60_000)
    expect(passed).toBeTruthy()

    // TC-6b: no errors
    const hasErrors = await jupyter.hasErrors()
    expect(hasErrors).toBeFalsy()

    // TC-6c: trained output line present
    const body = await jupyterTab.evaluate(() => document.body.innerText)
    expect(body).toContain('Trained:')

    await jupyterTab.close()
  })
})
