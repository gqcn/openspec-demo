/**
 * Shared test configuration constants.
 * Override via environment variables.
 */
export const config = {
  adminUser: process.env.E2E_ADMIN_USER || 'admin',
  adminPass: process.env.E2E_ADMIN_PASS || 'Admin@123456',
  testUser: process.env.E2E_TEST_USER || 'testuser01',
  testUserPass: process.env.E2E_TEST_USER_PASS || 'Test@123456',
  k8sNamespace: process.env.K8S_NAMESPACE || 'jupyter',
  // Max seconds to wait for a Pod to reach Running state.
  // Images must be pre-loaded into the kind cluster (make k8s-preload) to stay within this window.
  // Override via: E2E_TIMEOUT_POD=120 npx playwright test
  podTimeout: Number(process.env.E2E_TIMEOUT_POD) || 60,
}
