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
  podTimeout: Number(process.env.E2E_TIMEOUT_POD) || 120,
}
