import type { FullConfig } from '@playwright/test'

/**
 * Global teardown — runs once after all E2E tests complete.
 *
 * Cleans up test data created during the test run:
 *   1. Spec   "Test-CPU-E2E"  (created by TC0002f)
 *   2. User   config.testUser / testuser01  (created by TC0003d; used by TC0009)
 *   3. Any remaining notebook records owned by admin or testuser01
 *
 * Uses direct HTTP API calls (no browser) so it works regardless of
 * browser state after the test run.
 */
async function globalTeardown(config: FullConfig) {
  const baseURL = process.env.BASE_URL || 'http://localhost:3002'
  const adminUser = process.env.E2E_ADMIN_USER || 'admin'
  const adminPass = process.env.E2E_ADMIN_PASS || 'Admin@123456'
  const testUser = process.env.E2E_TEST_USER || 'testuser01'

  // ── 1. Authenticate as admin ──────────────────────────────────────────────
  let token: string
  try {
    const res = await fetch(`${baseURL}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: adminUser, password: adminPass }),
    })
    const data = (await res.json()) as { code: number; data?: { token?: string } }
    if (data.code !== 0 || !data.data?.token) {
      console.warn('[teardown] Admin login failed — skipping cleanup')
      return
    }
    token = data.data.token
  } catch (e) {
    console.warn('[teardown] Unable to reach backend — skipping cleanup:', e)
    return
  }

  const headers: Record<string, string> = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  }

  // ── 2. Delete Test-CPU-E2E spec ───────────────────────────────────────────
  try {
    const res = await fetch(`${baseURL}/api/spec`, { headers })
    const data = (await res.json()) as { code: number; data?: { list?: Array<{ id: number; name: string }> } }
    const spec = (data.data?.list ?? []).find((s) => s.name === 'Test-CPU-E2E')
    if (spec) {
      await fetch(`${baseURL}/api/spec/${spec.id}`, { method: 'DELETE', headers })
      console.log(`[teardown] Deleted spec "Test-CPU-E2E" (id=${spec.id})`)
    }
  } catch (e) {
    console.warn('[teardown] Spec cleanup failed:', e)
  }

  // ── 3. Delete testuser01 ──────────────────────────────────────────────────
  try {
    const res = await fetch(`${baseURL}/api/user`, { headers })
    const data = (await res.json()) as { code: number; data?: { list?: Array<{ id: number; username: string }> } }
    const user = (data.data?.list ?? []).find((u) => u.username === testUser)
    if (user) {
      await fetch(`${baseURL}/api/user/${user.id}`, { method: 'DELETE', headers })
      console.log(`[teardown] Deleted user "${testUser}" (id=${user.id})`)
    }
  } catch (e) {
    console.warn('[teardown] User cleanup failed:', e)
  }

  // ── 4. Delete remaining notebook records for admin / testuser01 ───────────
  try {
    const res = await fetch(`${baseURL}/api/notebook`, { headers })
    const data = (await res.json()) as { code: number; data?: { list?: Array<{ id: number; username: string; status: string }> } }
    const records = (data.data?.list ?? []).filter(
      (nb) => nb.username === adminUser || nb.username === testUser,
    )
    for (const nb of records) {
      await fetch(`${baseURL}/api/notebook/${nb.id}`, { method: 'DELETE', headers })
      console.log(`[teardown] Deleted notebook id=${nb.id} (user=${nb.username}, status=${nb.status})`)
    }
  } catch (e) {
    console.warn('[teardown] Notebook cleanup failed:', e)
  }
}

export default globalTeardown
