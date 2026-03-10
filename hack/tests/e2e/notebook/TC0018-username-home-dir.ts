import { test, expect } from '../../fixtures/auth'
import { NotebookPage } from '../../pages/NotebookPage'
import { waitPodReady, execInPod } from '../../fixtures/k8s'
import { config } from '../../fixtures/config'

test.describe('TC-18 开发机用户名与 home 目录', () => {
  test.setTimeout(300_000) // 5 min — pod startup can be slow

  test('TC-18a~d: Pod 内用户名为真实用户, home 路径为 /home/{username}', async ({ adminPage }) => {
    const nb = new NotebookPage(adminPage)

    // Ensure a clean notebook exists and is running
    await nb.cleanup()
    await nb.goto()
    await nb.createNotebook(0)

    // TC-18a: Wait for pod to be ready
    const podReady = await waitPodReady('jupyterlab-admin', config.podTimeout)
    expect(podReady, 'Pod should reach Running 1/1 state').toBeTruthy()

    // TC-18b: NB_USER env var should be set to "admin"
    const nbUser = execInPod('jupyterlab-admin', 'printenv NB_USER').trim()
    expect(nbUser, 'NB_USER env var should be set to real username').toBe('admin')

    // TC-18c: /home/admin should exist (as symlink to /data/home/admin)
    const homeTarget = execInPod('jupyterlab-admin', 'readlink -f /home/admin').trim()
    expect(homeTarget, '/home/admin should resolve to /data/home/admin').toBe('/data/home/admin')

    // TC-18d: The admin user was created by start.sh with correct home directory
    const passwdEntry = execInPod('jupyterlab-admin', 'getent passwd admin').trim()
    expect(passwdEntry, 'admin user should exist in /etc/passwd').toContain('admin')
    expect(passwdEntry, 'admin home should be /home/admin').toContain('/home/admin')
  })
})
