#!/usr/bin/env bash
# TC-5  等待 Pod Running，访问 JupyterLab (JupyterLab Access)
log ""
log "=== TC-5: 等待 Pod 就绪并访问 JupyterLab ==="
log "  等待 Pod Running（最多 ${TIMEOUT_POD}s）..."

POD_READY=false
if wait_pod_ready "jupyterlab-admin" "$TIMEOUT_POD"; then
  POD_READY=true
  pass "TC-5a: Pod jupyterlab-admin 状态 1/1 Running"
else
  fail "TC-5a: Pod Running" "${TIMEOUT_POD}s 内 Pod 未就绪"
fi

if [[ "$POD_READY" == "true" ]]; then
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 2

  assert_text "TC-5b: 实例状态显示运行中" "运行中"

  # Open JupyterLab via '进入' button
  pc_code "async page => {
    const btn = page.getByRole('button', { name: '进入' });
    if (await btn.isVisible()) await btn.click();
    await page.waitForTimeout(2000);
  }" >/dev/null 2>&1
  sleep 2

  # Switch to the new JupyterLab tab
  TAB_COUNT=$(run_timeout 8 playwright-cli tab-list 2>/dev/null | grep -c "^-" || echo "0")
  if [[ "$TAB_COUNT" -ge 2 ]]; then
    run_timeout 8 playwright-cli tab-select 1 >/dev/null 2>&1
    sleep 5

    # Wait up to 40s for JupyterLab DOM elements
    JP_LOADED=false
    for i in $(seq 1 40); do
      JP=$(run_timeout "$TIMEOUT_SHORT" playwright-cli run-code "async page => {
        const n = await page.locator('[class^=\"jp-\"]').count();
        return n > 5 ? 'true' : 'false';
      }" 2>/dev/null | get_result)
      if [[ "$JP" == "true" ]]; then JP_LOADED=true; break; fi
      sleep 1
    done
    if [[ "$JP_LOADED" == "true" ]]; then
      pass "TC-5c: JupyterLab UI 加载成功"
    else
      fail "TC-5c: JupyterLab UI 加载成功" "40s 内未检测到 JupyterLab DOM 元素"
    fi

    # File browser panel check
    FB=$(run_timeout "$TIMEOUT_SHORT" playwright-cli run-code "async page => {
      const n = await page.locator('.jp-FileBrowser, .jp-BreadCrumbs, .jp-DirListing').count();
      return n > 0 ? 'true' : 'false';
    }" 2>/dev/null | get_result)
    if [[ "$FB" == "true" ]]; then
      pass "TC-5d: 文件浏览器可见"
    else
      fail "TC-5d: 文件浏览器可见" "未检测到文件浏览器 DOM 元素"
    fi
  else
    fail "TC-5c: JupyterLab UI 加载成功" "未检测到 JupyterLab 标签页"
    fail "TC-5d: 文件浏览器可见" "Tab 未打开"
  fi
fi
