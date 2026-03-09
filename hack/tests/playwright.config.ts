import { defineConfig, devices } from '@playwright/test'

/**
 * AI Training Platform — Playwright E2E Configuration
 *
 * Environment variables:
 *   BASE_URL          Frontend URL         (default: http://localhost:3002)
 *   E2E_TIMEOUT_POD   Max seconds to wait for K8s pod  (default: 120)
 *   K8S_NAMESPACE     Kubernetes namespace  (default: jupyter)
 */
export default defineConfig({
  testDir: './e2e',
  testMatch: /TC\d{4}.*\.ts$/,
  fullyParallel: false,           // tests have sequential dependencies (login → create → jupyter)
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,                     // single worker — shared K8s cluster state
  timeout: 180_000,               // 3 min per test (pod startup can be slow)
  expect: { timeout: 10_000 },

  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
  ],

  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3002',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
})
