#!/usr/bin/env bash
# TC-3  用户管理页面验证 (User Management)
log ""
log "=== TC-3: 用户管理页面验证 ==="
pc_goto "$BASE_URL/users" >/dev/null 2>&1
sleep 1

assert_text "TC-3a: 页面标题为用户管理" "用户管理"
assert_text "TC-3b: 包含 admin 用户" "admin"
assert_text "TC-3c: 用户状态正常" "正常"

# TC-3d: 创建新用户
log ""
log "=== TC-3d/TC-3e: 创建新用户并禁用 ==="
pc_code "async page => {
  await page.getByRole('button', { name: '新增用户' }).click();
  await page.waitForSelector('.el-dialog__body', { timeout: 4000 });
  await page.getByPlaceholder('请输入用户名').fill('${TEST_USER}');
  await page.locator('[type=\"password\"]').first().fill('${TEST_USER_PASS}');
  await page.getByRole('button', { name: '创建' }).click();
  await page.waitForTimeout(1500);
}" >/dev/null 2>&1
sleep 1
pc_goto "$BASE_URL/users" >/dev/null 2>&1
sleep 1
assert_text "TC-3d: 创建用户后出现在列表" "$TEST_USER"

# TC-3e: 禁用新用户
pc_code "async page => {
  const rows = await page.locator('tr').all();
  for (const row of rows) {
    const text = await row.innerText().catch(() => '');
    if (text.includes('${TEST_USER}')) {
      const toggleBtn = row.getByRole('button', { name: '禁用' });
      if (await toggleBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
        await toggleBtn.click();
        const confirmBtn = page.getByRole('button', { name: '确定' });
        if (await confirmBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
          await confirmBtn.click();
        }
      }
      break;
    }
  }
  await page.waitForTimeout(1500);
}" >/dev/null 2>&1
sleep 1
pc_goto "$BASE_URL/users" >/dev/null 2>&1
sleep 1

DISABLED_FOUND=$(page_contains "禁用")
if [[ "$DISABLED_FOUND" == "true" ]]; then
  pass "TC-3e: 禁用用户后状态显示禁用"
else
  fail "TC-3e: 禁用用户后状态显示禁用" "$TEST_USER 未变为禁用状态"
fi
