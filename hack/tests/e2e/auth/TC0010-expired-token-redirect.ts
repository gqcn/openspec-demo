import { test, expect } from '../../fixtures/auth'
import { config } from '../../fixtures/config'

test.describe('TC0010 过期/无效 Token 自动跳转登录', () => {
  test('TC0010a: 使用无效 token 访问 /notebooks 后跳转到 /login', async ({ page }) => {
    // Set an invalid token in localStorage to simulate expired session
    await page.goto('/login')
    await page.evaluate(() => {
      localStorage.setItem('token', 'invalid-expired-token-abc123')
      localStorage.setItem('userInfo', JSON.stringify({
        id: 1, username: 'admin', isAdmin: 1, uid: 10001
      }))
    })

    // Navigate to a protected page — router guard detects invalid token and redirects immediately
    await page.goto('/notebooks')

    await page.waitForURL('**/login', { timeout: 10_000 })
    expect(page.url()).toContain('/login')
  })

  test('TC0010b: 无效 token 跳转后 localStorage token 已清除', async ({ page }) => {
    await page.goto('/login')
    await page.evaluate(() => {
      localStorage.setItem('token', 'invalid-expired-token-abc123')
      localStorage.setItem('userInfo', JSON.stringify({
        id: 1, username: 'admin', isAdmin: 1, uid: 10001
      }))
    })

    await page.goto('/notebooks')
    await page.waitForURL('**/login', { timeout: 10_000 })

    const token = await page.evaluate(() => localStorage.getItem('token'))
    expect(token).toBeFalsy()
  })

  test('TC0010c: 使用过期 JWT token 访问 /notebooks 后立即跳转到 /login', async ({ page }) => {
    // Build a JWT-like token with an expired `exp` claim (past timestamp)
    const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
    const payload = btoa(JSON.stringify({
      userId: 1, username: 'admin', isAdmin: 1, uid: 10001,
      exp: Math.floor(Date.now() / 1000) - 3600 // expired 1 hour ago
    }))
    const expiredToken = `${header}.${payload}.fakesignature`

    await page.goto('/login')
    await page.evaluate((tok) => {
      localStorage.setItem('token', tok)
      localStorage.setItem('userInfo', JSON.stringify({
        id: 1, username: 'admin', isAdmin: 1, uid: 10001
      }))
    }, expiredToken)

    // Navigate — router guard decodes JWT, sees exp is past, clears auth, redirects
    await page.goto('/notebooks')
    await page.waitForURL('**/login', { timeout: 5_000 })
    expect(page.url()).toContain('/login')

    const token = await page.evaluate(() => localStorage.getItem('token'))
    expect(token).toBeFalsy()
  })
})
