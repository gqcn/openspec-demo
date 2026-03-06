#!/usr/bin/env bash
# =============================================================================
# actions.sh  —  Reusable high-level actions (login, logout, notebook CRUD, etc.)
#
# These functions encapsulate the repeated playwright-cli interactions that
# appear across multiple test cases, eliminating duplication.
# =============================================================================

# ── Auth actions ─────────────────────────────────────────────────────────────

# Login as specified user. Usage: do_login <username> <password>
do_login() {
  local user="$1" pass="$2"
  pc_goto "$BASE_URL/login" >/dev/null 2>&1
  sleep 0.5
  pc_code "async page => {
    await page.getByPlaceholder('请输入用户名').fill('${user}');
    await page.getByPlaceholder('请输入密码').fill('${pass}');
    await page.getByRole('button', { name: '登 录' }).click();
    await page.waitForURL('**/notebooks', { timeout: 8000 });
  }" >/dev/null 2>&1
  sleep 1
}

# Logout current user. Usage: do_logout [displayed_username]
do_logout() {
  local display_name="${1:-admin}"
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 1
  run_timeout "$TIMEOUT_LONG" playwright-cli run-code "async page => {
    const btn = page.getByRole('button', { name: '${display_name}' });
    if (await btn.count() > 0) {
      await btn.click({ timeout: 3000 }).catch(async () => {
        await page.locator('.el-header .el-dropdown, .el-header [tabindex=\"0\"]').first().click();
      });
    } else {
      await page.locator('.el-header .el-dropdown, .el-header [tabindex=\"0\"]').first().click();
    }
    await page.waitForTimeout(500);
    await page.getByRole('menuitem', { name: '退出登录' }).click({ timeout: 5000 });
    await page.waitForURL('**/login', { timeout: 8000 }).catch(() => {});
  }" >/dev/null 2>&1
  sleep 1
}

# ── Notebook actions ─────────────────────────────────────────────────────────

# Create a notebook selecting the Nth image option (0-based). Default: first.
# Usage: do_create_notebook [image_index]
do_create_notebook() {
  local image_index="${1:-0}"
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 1
  run_timeout "$TIMEOUT_LONG" playwright-cli run-code "async page => {
    await page.getByRole('button', { name: '创建开发机' }).click();
    await page.waitForSelector('.spec-card', { timeout: 5000 });
    await page.waitForTimeout(300);
    await page.locator('.spec-card').first().click();
    await page.locator('.el-select__wrapper').first().click();
    await page.waitForSelector('[role=\"option\"]', { timeout: 3000 });
    const opts = await page.locator('[role=\"option\"]').all();
    await opts[Math.min(${image_index}, opts.length - 1)].click();
    await page.getByRole('button', { name: '创建', exact: true }).click();
    await page.waitForTimeout(2000);
  }" >/dev/null 2>&1
  sleep 2
}

# Stop the active notebook instance (click stop + confirm dialog).
do_stop_notebook() {
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 2
  pc_code "async page => {
    const stopBtns = await page.getByRole('button', { name: '停止' }).all();
    if (stopBtns.length > 0) {
      await stopBtns[0].click();
      try {
        const msgBox = page.locator('.el-message-box');
        await msgBox.waitFor({ state: 'visible', timeout: 3000 });
        await msgBox.getByRole('button', { name: '停止', exact: true }).click();
      } catch(e) {}
    }
    await page.waitForTimeout(3000);
  }" >/dev/null 2>&1
}

# Delete stopped/failed notebook record.
do_delete_notebook_record() {
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 1
  pc_code "async page => {
    const delBtns = await page.getByRole('button', { name: '删除记录' }).all();
    if (delBtns.length > 0) {
      await delBtns[0].click();
      const confirmBtn = page.getByRole('button', { name: '删除', exact: true });
      if (await confirmBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
        await confirmBtn.click();
      }
      await page.waitForTimeout(1500);
    }
  }" >/dev/null 2>&1
  sleep 1
}

# Wait until no active notebook (运行中/创建中/停止中). Max ~60s.
wait_notebook_stopped() {
  local max_iters="${1:-12}"
  for i in $(seq 1 "$max_iters"); do
    pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
    sleep 3
    local still_active
    still_active=$(run_timeout 8 playwright-cli run-code "async page => {
      const body = await page.evaluate(() => document.body.innerText);
      return (body.includes('运行中') || body.includes('创建中') || body.includes('停止中')) ? 'true' : 'false';
    }" 2>/dev/null | get_result)
    [[ "$still_active" != "true" ]] && return 0
    log "  ($i/$max_iters) 等待实例停止..."
  done
  return 1
}

# Check if page has an active notebook
has_active_notebook() {
  local result
  result=$(run_timeout "$TIMEOUT_SHORT" playwright-cli run-code "async page => {
    const body = await page.evaluate(() => document.body.innerText);
    return (body.includes('运行中') || body.includes('创建中') || body.includes('停止中')) ? 'true' : 'false';
  }" 2>/dev/null | get_result)
  [[ "$result" == "true" ]]
}

# Check if page has a stopped/failed notebook
has_stopped_notebook() {
  local result
  result=$(run_timeout 8 playwright-cli run-code "async page => {
    const body = await page.evaluate(() => document.body.innerText);
    return (body.includes('已停止') || body.includes('异常')) ? 'true' : 'false';
  }" 2>/dev/null | get_result)
  [[ "$result" == "true" ]]
}

# Full cleanup: stop active + delete stopped record, leaving a clean slate.
do_cleanup_notebooks() {
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 2
  if has_active_notebook; then
    log "  清理: 停止活跃实例..."
    do_stop_notebook
    wait_notebook_stopped
  fi
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 1
  if has_stopped_notebook; then
    log "  清理: 删除已停止记录..."
    do_delete_notebook_record
  fi
}

# ── Kubernetes helpers ───────────────────────────────────────────────────────

# Wait for a pod to be 1/1 Running. Usage: wait_pod_ready <pod_name> [max_seconds]
wait_pod_ready() {
  local pod_name="$1" max_secs="${2:-$TIMEOUT_POD}"
  local iters=$(( max_secs / 5 ))
  for i in $(seq 1 "$iters"); do
    local status ready
    status=$(kubectl -n "$K8S_NAMESPACE" get pod "$pod_name" --no-headers 2>/dev/null | awk '{print $3}' || echo "")
    ready=$(kubectl -n "$K8S_NAMESPACE" get pod "$pod_name" --no-headers 2>/dev/null | awk '{print $2}' || echo "")
    if [[ "$status" == "Running" && "$ready" == "1/1" ]]; then
      log "  Pod $pod_name 1/1 Running ✓"
      return 0
    fi
    log "  ($i/$iters) Pod $pod_name 状态: $status $ready — 等待5s..."
    sleep 5
  done
  return 1
}

# ── API helpers ──────────────────────────────────────────────────────────────

# Call API from browser context. Usage: browser_api <js_code_returning_value>
browser_api() {
  local js_code="$1"
  run_timeout "$TIMEOUT_SHORT" playwright-cli run-code "async page => {
    return await page.evaluate(async () => {
      const token = localStorage.getItem('token') || '';
      ${js_code}
    });
  }" 2>/dev/null | get_result
}

# Enable a user by username via API (from current browser session).
do_enable_user() {
  local username="$1"
  browser_api "
    const lr = await fetch('/api/user', { headers: { 'Authorization': 'Bearer ' + token } });
    const ld = await lr.json();
    const list = (ld.data && ld.data.list) ? ld.data.list : [];
    const user = list.find(u => u.username === '${username}');
    if (!user) return 'user-not-found';
    const ur = await fetch('/api/user/' + user.id + '/status', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
      body: JSON.stringify({ status: 1 })
    });
    const ud = await ur.json();
    return ud.code === 0 ? 'enabled' : 'enable-failed:' + ud.message;
  "
}
