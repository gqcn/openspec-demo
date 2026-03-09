import { test, expect } from '../../fixtures/auth'
import { NotebookPage } from '../../pages/NotebookPage'
import { JupyterLabPage } from '../../pages/JupyterLabPage'
import { waitPodReady } from '../../fixtures/k8s'
import { config } from '../../fixtures/config'

test.describe('TC0006 训练代码执行', () => {
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

  test('TC0006a~c: JupyterLab 中执行训练代码', async ({ adminPage, context }) => {
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

    // TC0006a: output contains marker
    const passed = await jupyter.waitForOutput('TRAINING_TEST_PASSED', 60_000)
    expect(passed).toBeTruthy()

    // TC0006b: no errors
    const hasErrors = await jupyter.hasErrors()
    expect(hasErrors).toBeFalsy()

    // TC0006c: trained output line present
    const body = await jupyterTab.evaluate(() => document.body.innerText)
    expect(body).toContain('Trained:')

    await jupyterTab.close()
  })
})
