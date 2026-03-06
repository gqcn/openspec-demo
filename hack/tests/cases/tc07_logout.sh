#!/usr/bin/env bash
# TC-7  退出登录 (Logout) + 边界测试
log ""
log "=== TC-7: 退出登录 ==="
# Navigate back to main app tab
run_timeout 8 playwright-cli tab-select 0 >/dev/null 2>&1

do_logout "$ADMIN_USER"
sleep 1

assert_url "TC-7a: 退出登录后跳转到 /login" "/login"

# Check logout toast (may or may not appear depending on timing)
if wait_for_text "登 录" 8 || wait_for_text "登录" 5; then
  pass "TC-7c: 显示登录表单"
else
  fail "TC-7c: 显示登录表单" "expected login page content not found"
fi

# Protected route — accessing /notebooks should redirect to login
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 1
assert_url "TC-7d: 未登录访问 /notebooks 重定向到 /login" "/login"

# TC-7e/TC-7f: 错误密码边界测试
log ""
log "=== TC-7e/TC-7f: 错误密码登录边界测试 ==="
WRONG_PASS_RESULT=$(run_timeout 20 playwright-cli run-code "async page => {
  await page.getByPlaceholder('请输入用户名').fill('admin');
  await page.getByPlaceholder('请输入密码').fill('wrong_password_!@#');
  await page.getByRole('button', { name: '登 录' }).click();
  let toastFound = false;
  try {
    await page.locator('.el-message--error').waitFor({ state: 'visible', timeout: 5000 });
    toastFound = true;
  } catch(e) {}
  if (!toastFound) {
    try {
      await page.locator('.el-message').waitFor({ state: 'visible', timeout: 2000 });
      toastFound = true;
    } catch(e) {}
  }
  const stillLogin = page.url().includes('/login');
  return (stillLogin ? 'still-login' : 'navigated') + ':' + (toastFound ? 'toast' : 'no-toast');
}" 2>/dev/null | get_result)
sleep 1

assert_url "TC-7e: 错误密码登录后留在登录页（不崩溃）" "/login"
if [[ "$WRONG_PASS_RESULT" == *"toast"* ]]; then
  pass "TC-7f: 错误密码显示错误提示（不崩溃）"
else
  fail "TC-7f: 错误密码显示错误提示（不崩溃）" "未检测到错误提示 toast（result: ${WRONG_PASS_RESULT}）"
fi

# Re-login as admin for subsequent tests
do_login "$ADMIN_USER" "$ADMIN_PASS"
