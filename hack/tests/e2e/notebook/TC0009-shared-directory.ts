import { test, expect } from '../../fixtures/auth'
import { NotebookPage } from '../../pages/NotebookPage'
import { UserPage } from '../../pages/UserPage'
import { LoginPage } from '../../pages/LoginPage'
import { MainLayout } from '../../pages/MainLayout'
import { waitPodReady, execInPod } from '../../fixtures/k8s'
import { config } from '../../fixtures/config'

test.describe('TC0009 多用户 /share 共享目录', () => {
  test.setTimeout(600_000) // 10 min — two pods to spin up

  const shareFileAdmin = `admin_share_test_${Date.now()}.txt`
  const shareFileUser = `${config.testUser}_share_test_${Date.now()}.txt`

  test('TC0009a~d: 多用户共享目录读写验证', async ({ adminPage }) => {
    const nb = new NotebookPage(adminPage)
    const userPage = new UserPage(adminPage)
    const layout = new MainLayout(adminPage)

    // ── Step 0: Clean up and create admin notebook ──
    await nb.cleanup()
    await nb.goto()
    await nb.createNotebook(0)

    // ── Step 1: Wait for admin pod ──
    const adminPodReady = await waitPodReady('jupyterlab-admin', config.podTimeout)
    if (!adminPodReady) {
      test.skip(true, 'Admin pod not ready — skipping TC0009')
      return
    }

    // ── Step 2: Admin writes to /share (TC0009a) ──
    const adminWrite = execInPod(
      'jupyterlab-admin',
      `echo 'hello from admin' > /share/${shareFileAdmin} && cat /share/${shareFileAdmin}`,
    )
    expect(adminWrite).toContain('hello from admin')

    // ── Step 3: Stop admin notebook ──
    await nb.goto()
    await nb.stopNotebook()
    await nb.waitUntilStopped()
    await nb.goto()
    await nb.deleteRecord()

    // ── Step 4: Re-enable testuser01 ──
    const enableResult = await userPage.enableUserViaApi(config.testUser)
    expect(['enabled', 'user-not-found']).toContain(enableResult)

    // ── Step 5: Switch to testuser01 ──
    await layout.logout(config.adminUser)
    const loginPage = new LoginPage(adminPage)
    await loginPage.goto()
    await loginPage.loginAndWaitForRedirect(config.testUser, config.testUserPass)

    // ── Step 6: Create notebook for testuser01 ──
    const nbUser = new NotebookPage(adminPage)
    await nbUser.goto()
    if (await nbUser.hasStoppedNotebook()) {
      await nbUser.deleteRecord()
    }
    await nbUser.goto()
    await nbUser.createNotebook(0)

    // ── Step 7: Wait for testuser01 pod ──
    const userPodReady = await waitPodReady(`jupyterlab-${config.testUser}`, config.podTimeout)
    if (!userPodReady) {
      test.skip(true, 'Test user pod not ready — skipping share verification')
      return
    }

    // ── Step 8: TC0009b — testuser01 can read admin's file ──
    const userRead = execInPod(
      `jupyterlab-${config.testUser}`,
      `cat /share/${shareFileAdmin}`,
    )
    expect(userRead).toContain('hello from admin')

    // ── Step 9: TC0009c — testuser01 can write to /share ──
    const userWrite = execInPod(
      `jupyterlab-${config.testUser}`,
      `echo 'hello from ${config.testUser}' > /share/${shareFileUser} && cat /share/${shareFileUser}`,
    )
    expect(userWrite).toContain(`hello from ${config.testUser}`)

    // ── Step 10: TC0009d — both files exist ──
    const bothFiles = execInPod(
      `jupyterlab-${config.testUser}`,
      `ls /share/${shareFileAdmin} /share/${shareFileUser} && echo BOTH_EXIST`,
    )
    expect(bothFiles).toContain('BOTH_EXIST')

    // ── Cleanup ──
    execInPod(
      `jupyterlab-${config.testUser}`,
      `rm -f /share/${shareFileAdmin} /share/${shareFileUser}`,
    )
    await nbUser.goto()
    await nbUser.stopNotebook()
    await nbUser.waitUntilStopped()

    // Switch back to admin
    const layoutUser = new MainLayout(adminPage)
    await layoutUser.logout(config.testUser)
    await loginPage.goto()
    await loginPage.loginAndWaitForRedirect(config.adminUser, config.adminPass)
  })
})
