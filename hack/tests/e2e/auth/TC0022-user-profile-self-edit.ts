import { expect } from '@playwright/test';
import { test } from '../../fixtures/auth';

test.describe('TC0022 - User Profile Self-Edit', () => {
  test('TC0022a - Can navigate to profile page', async ({ adminPage }) => {
    // Navigate to profile page directly
    await adminPage.goto('http://localhost:3002/profile');
    await adminPage.waitForLoadState('networkidle');

    // Check if we're on the profile page
    await expect(adminPage).toHaveURL(/.*profile/);
  });

  test('TC0022b - Profile page displays two-column layout', async ({ adminPage }) => {
    await adminPage.goto('http://localhost:3002/profile');
    await adminPage.waitForLoadState('networkidle');

    // Check left card with user info is visible
    const userCard = adminPage.locator('.ant-card').first();
    await expect(userCard).toBeVisible();

    // Check username is displayed in the card (use first to avoid strict mode)
    await expect(adminPage.locator('text=admin').first()).toBeVisible();

    // Check right card with tabs is visible
    const tabsCard = adminPage.locator('.ant-card').nth(1);
    await expect(tabsCard).toBeVisible();

    // Check tabs exist
    await expect(adminPage.locator('text=基本设置')).toBeVisible();
    await expect(adminPage.locator('text=安全设置')).toBeVisible();
  });

  test('TC0022c - Left card displays user information from backend', async ({ adminPage }) => {
    await adminPage.goto('http://localhost:3002/profile');
    await adminPage.waitForLoadState('networkidle');

    // Check avatar is visible
    const avatar = adminPage.locator('.ant-avatar').first();
    await expect(avatar).toBeVisible();

    // Check username is displayed (use first to avoid strict mode)
    await expect(adminPage.locator('.text-xl.font-semibold:has-text("admin")')).toBeVisible();

    // Check account info section
    await expect(adminPage.locator('text=账号：')).toBeVisible();

    // Check email info section
    await expect(adminPage.locator('text=邮箱：')).toBeVisible();

    // Check role is displayed (admin user should have 'admin' role)
    await expect(adminPage.locator('text=角色：')).toBeVisible();
    await expect(adminPage.locator('.bg-blue-50.text-blue-600:has-text("admin")')).toBeVisible();
  });

  test('TC0022d - Can update email and see updated value in left panel', async ({ adminPage }) => {
    await adminPage.goto('http://localhost:3002/profile');
    await adminPage.waitForLoadState('networkidle');

    // Make sure we're on the basic settings tab (should be default)
    const basicTab = adminPage.locator('text=基本设置');
    await basicTab.click();
    await adminPage.waitForTimeout(300);

    // Generate unique email to avoid conflicts
    const uniqueEmail = `test-${Date.now()}@example.com`;

    // Find and fill email input
    const emailInput = adminPage.locator('input[placeholder*="邮箱"]');
    await emailInput.clear();
    await emailInput.fill(uniqueEmail);

    // Submit
    const submitButton = adminPage.locator('button:has-text("更新信息")');
    await submitButton.click();

    // Wait for success message
    await expect(adminPage.locator('.ant-message:has-text("邮箱已更新")')).toBeVisible({ timeout: 5000 });

    // Verify the left panel shows the updated email (refresh should have happened)
    await adminPage.waitForTimeout(1000);
    await expect(adminPage.locator(`text=${uniqueEmail}`)).toBeVisible({ timeout: 5000 });
  });

  test('TC0022e - Email validation shows error for invalid format', async ({ adminPage }) => {
    await adminPage.goto('http://localhost:3002/profile');
    await adminPage.waitForLoadState('networkidle');

    // Make sure we're on the basic settings tab
    const basicTab = adminPage.locator('text=基本设置');
    await basicTab.click();
    await adminPage.waitForTimeout(300);

    // Enter invalid email
    const emailInput = adminPage.locator('input[placeholder*="邮箱"]');
    await emailInput.clear();
    await emailInput.fill('invalid-email');

    // Trigger validation by moving focus
    await adminPage.keyboard.press('Tab');

    // Wait for validation error message
    await expect(adminPage.locator('text=请输入有效的邮箱地址')).toBeVisible({ timeout: 3000 });
  });

  test('TC0022f - Password validation shows error for less than 8 characters', async ({ adminPage }) => {
    await adminPage.goto('http://localhost:3002/profile');
    await adminPage.waitForLoadState('networkidle');

    // Click on security settings tab
    const securityTab = adminPage.locator('text=安全设置');
    await securityTab.click();
    await adminPage.waitForTimeout(300);

    // Enter short password
    const passwordInput = adminPage.locator('input[placeholder*="新密码"]').first();
    await passwordInput.fill('short');

    // Trigger validation by moving focus
    await adminPage.locator('input[placeholder*="再次输入"]').click();

    // Wait for validation error message
    await expect(adminPage.locator('text=密码至少8位')).toBeVisible({ timeout: 3000 });
  });

  test('TC0022g - Password mismatch shows error', async ({ adminPage }) => {
    await adminPage.goto('http://localhost:3002/profile');
    await adminPage.waitForLoadState('networkidle');

    // Click on security settings tab
    const securityTab = adminPage.locator('text=安全设置');
    await securityTab.click();
    await adminPage.waitForTimeout(300);

    // Fill mismatched passwords
    const passwordInput = adminPage.locator('input[placeholder*="新密码"]').first();
    const confirmPasswordInput = adminPage.locator('input[placeholder*="再次输入"]');

    await passwordInput.fill('password123');
    await confirmPasswordInput.fill('password456');

    // Submit
    const submitButton = adminPage.locator('button:has-text("更新密码")');
    await submitButton.click();

    // Wait for error message
    await expect(adminPage.locator('.ant-message:has-text("两次输入的密码不一致")')).toBeVisible({ timeout: 3000 });
  });

  test('TC0022h - Tab switching works correctly', async ({ adminPage }) => {
    await adminPage.goto('http://localhost:3002/profile');
    await adminPage.waitForLoadState('networkidle');

    // Default should be basic settings tab
    await expect(adminPage.locator('input[placeholder*="邮箱"]')).toBeVisible();

    // Switch to security settings tab
    const securityTab = adminPage.locator('text=安全设置');
    await securityTab.click();
    await adminPage.waitForTimeout(300);

    // Check security tab content is visible
    await expect(adminPage.locator('input[placeholder*="新密码"]').first()).toBeVisible();
    await expect(adminPage.locator('button:has-text("更新密码")')).toBeVisible();

    // Switch back to basic settings
    const basicTab = adminPage.locator('text=基本设置');
    await basicTab.click();
    await adminPage.waitForTimeout(300);

    // Check basic tab content is visible again
    await expect(adminPage.locator('input[placeholder*="邮箱"]')).toBeVisible();
    await expect(adminPage.locator('button:has-text("更新信息")')).toBeVisible();
  });

  // Password change test - runs last to avoid affecting other tests
  // After this test, the admin password will be changed
  test.describe.configure({ mode: 'serial' });

  test('TC0022i - Can update password successfully', async ({ adminPage }) => {
    await adminPage.goto('http://localhost:3002/profile');
    await adminPage.waitForLoadState('networkidle');

    // Click on security settings tab
    const securityTab = adminPage.locator('text=安全设置');
    await securityTab.click();
    await adminPage.waitForTimeout(300);

    // Use a known password that can be restored
    const newPassword = 'Admin@123456';

    // Find password inputs
    const passwordInput = adminPage.locator('input[placeholder*="新密码"]').first();
    const confirmPasswordInput = adminPage.locator('input[placeholder*="再次输入"]');

    // Fill password fields
    await passwordInput.fill(newPassword);
    await confirmPasswordInput.fill(newPassword);

    // Submit
    const submitButton = adminPage.locator('button:has-text("更新密码")');
    await submitButton.click();

    // Wait for success message
    await expect(adminPage.locator('.ant-message:has-text("密码已更新")')).toBeVisible({ timeout: 5000 });
  });
});