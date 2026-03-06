#!/usr/bin/env bash
# TC-8  不同镜像开发机创建测试
log ""
log "=== TC-8: 不同镜像（PyTorch）开发机创建测试 ==="

# Cleanup existing notebooks
do_cleanup_notebooks

# Verify create button is enabled
BTN_ENABLED=$(run_timeout "$TIMEOUT_SHORT" playwright-cli run-code "async page => {
  const btn = page.getByRole('button', { name: '创建开发机' });
  try {
    const isDisabled = await btn.isDisabled({ timeout: 3000 });
    return isDisabled ? 'false' : 'true';
  } catch(e) { return 'error'; }
}" 2>/dev/null | get_result)
BTN_ENABLED=${BTN_ENABLED:-}
if [[ "$BTN_ENABLED" == "true" ]]; then
  pass "TC-8b: 清除记录后创建按钮已启用"
else
  fail "TC-8b: 清除记录后创建按钮已启用" "按钮仍禁用（result: ${BTN_ENABLED}）"
fi

# Create notebook with the last image option (PyTorch)
# Use special index -1 logic: select last option
run_timeout "$TIMEOUT_LONG" playwright-cli run-code "async page => {
  await page.getByRole('button', { name: '创建开发机' }).click();
  await page.waitForSelector('.spec-card', { timeout: 5000 });
  await page.waitForTimeout(300);
  await page.locator('.spec-card').first().click();
  await page.locator('.el-select__wrapper').first().click();
  await page.waitForSelector('[role=\"option\"]', { timeout: 3000 });
  const opts = await page.locator('[role=\"option\"]').all();
  const lastOpt = opts[opts.length - 1];
  await lastOpt.click();
  await page.getByRole('button', { name: '创建', exact: true }).click();
  await page.waitForTimeout(2000);
}" >/dev/null 2>&1
sleep 2
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 2

# TC-8c: Verify pytorch image appears
PYTORCH_FOUND=$(run_timeout "$TIMEOUT_SHORT" playwright-cli run-code "async page => {
  const body = await page.evaluate(() => document.body.innerText);
  return (body.includes('pytorch-cuda121') || body.includes('PyTorch')) ? 'true' : 'false';
}" 2>/dev/null | get_result)
if [[ "$PYTORCH_FOUND" == "true" ]]; then
  pass "TC-8c: 使用 PyTorch 镜像创建的开发机显示正确镜像"
else
  fail "TC-8c: 使用 PyTorch 镜像创建的开发机显示正确镜像" "列表中未找到 pytorch-notebook"
fi

# TC-8d: Verify the new notebook is in creating/running state
if wait_for_text "创建中" 5 || wait_for_text "运行中" 5; then
  pass "TC-8d: PyTorch 开发机实例已创建"
else
  fail "TC-8d: PyTorch 开发机实例已创建" "实例未出现创建中/运行中状态"
fi
