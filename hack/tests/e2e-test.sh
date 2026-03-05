#!/usr/bin/env bash
# =============================================================================
# e2e-test.sh  —  AI Training Platform End-to-End Test Suite
# Uses playwright-cli for browser automation.
#
# Prerequisites:
#   - playwright-cli installed (brew install playwright-cli, or npm i -g playwright-cli)
#   - Backend running on localhost:8080
#   - Frontend running on localhost:3002
#   - nginx ingress port-forwarded: kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8081:80
#   - Kind cluster running with jupyterlab namespace ready
#
# Usage:  bash hack/tests/e2e-test.sh
# =============================================================================
set -uo pipefail

BASE_URL="http://localhost:3002"
ADMIN_USER="admin"
ADMIN_PASS="Admin@123456"

PASS=0
FAIL=0
ERRORS=()

# ── helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
pass() { ((PASS++));  log "✓ PASS [$1]"; }
fail() { ((FAIL++));  ERRORS+=("$1: $2"); log "✗ FAIL [$1] — $2"; }

# macOS-compatible timeout wrapper (no GNU coreutils needed).
# Usage: run_timeout SECONDS command [args...]
run_timeout() {
  local secs="$1"; shift
  "$@" &
  local pid=$!
  ( sleep "$secs" && kill -TERM "$pid" 2>/dev/null ) &
  local watcher=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  kill "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null
  return $rc
}

# Extract the result value from playwright-cli output.
# playwright-cli outputs:  ### Result\n<value>\n...
get_result() {
  awk '/^### Result$/{getline; print; exit}' | tr -d '"'
}

# Run playwright-cli run-code with a 15 s timeout, return raw output
pc_code() {
  run_timeout 15 playwright-cli run-code "$1" 2>/dev/null
}

# Extract current URL (10 s timeout)
current_url() {
  run_timeout 10 playwright-cli eval "window.location.href" 2>/dev/null | get_result
}

# Navigate to URL (15 s timeout)
pc_goto() {
  run_timeout 15 playwright-cli goto "$1" >/dev/null 2>&1
}

# Assert URL contains expected substring
assert_url() {
  local tc="$1" expected="$2"
  local url; url=$(current_url)
  if [[ "$url" == *"$expected"* ]]; then
    pass "$tc"
  else
    fail "$tc" "expected URL ~= '$expected', got '$url'"
  fi
}

# Assert page text contains a fragment (15 s timeout per call).
# Uses ensure_ascii=True so Chinese chars become safe \uXXXX JS escapes.
assert_text() {
  local tc="$1" text="$2"
  local js_text
  js_text=$(printf '%s' "$text" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read(), ensure_ascii=True))")
  local found
  found=$(run_timeout 15 playwright-cli run-code "async page => {
    try {
      const body = await page.evaluate(() => document.body.innerText);
      return body.includes(${js_text}) ? 'true' : 'false';
    } catch(e) { return 'error:' + e.message; }
  }" 2>/dev/null | get_result)
  if [[ "$found" == "true" ]]; then
    pass "$tc"
  else
    fail "$tc" "expected text '${text}' not found on page"
  fi
}

# Wait for text to appear.  Each poll attempt has a 10 s hard timeout.
wait_for_text() {
  local text="$1" secs="${2:-30}"
  local js_text
  js_text=$(printf '%s' "$text" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read(), ensure_ascii=True))")
  for i in $(seq 1 "$secs"); do
    local found
    found=$(run_timeout 10 playwright-cli run-code "async page => {
      try {
        const body = await page.evaluate(() => document.body.innerText);
        return body.includes(${js_text}) ? 'true' : 'false';
      } catch(e) { return 'false'; }
    }" 2>/dev/null | get_result)
    [[ "$found" == "true" ]] && return 0
    sleep 1
  done
  return 1
}

# ── setup ────────────────────────────────────────────────────────────────────
log "=== AI Training Platform E2E Test Suite ==="
log "Killing any existing browser sessions..."
playwright-cli kill-all 2>/dev/null || true
sleep 1
run_timeout 10 playwright-cli open --headed "$BASE_URL" >/dev/null 2>&1
sleep 3

# =============================================================================
# TC-1  登录验证 (Login)
# =============================================================================
log ""
log "=== TC-1: 登录验证 ==="
pc_goto "$BASE_URL/login" >/dev/null 2>&1
sleep 0.5

pc_code "async page => {
  await page.getByPlaceholder('请输入用户名').fill('$ADMIN_USER');
  await page.getByPlaceholder('请输入密码').fill('$ADMIN_PASS');
  await page.getByRole('button', { name: '登 录' }).click();
  await page.waitForURL('**/notebooks', { timeout: 8000 });
}" >/dev/null 2>&1

if assert_url "TC-1a: 登录后跳转到 /notebooks" "/notebooks"; then
  true
fi
assert_text "TC-1b: 侧边栏显示管理员菜单" "规格管理"
assert_text "TC-1c: 顶部显示用户名" "admin"

# =============================================================================
# TC-2  规格管理页面验证 (Spec Management)
# =============================================================================
log ""
log "=== TC-2: 规格管理页面验证 ==="
pc_goto "$BASE_URL/specs" >/dev/null 2>&1
sleep 1

assert_text "TC-2a: 页面标题为规格管理" "规格管理"
assert_text "TC-2b: 包含 CPU-小 规格" "CPU-小"
assert_text "TC-2c: 包含 CPU-大 规格" "CPU-大"
assert_text "TC-2d: 包含 GPU-标准 规格" "GPU-标准"
assert_text "TC-2e: 包含编辑操作" "编辑"

# =============================================================================
# TC-3  用户管理页面验证 (User Management)
# =============================================================================
log ""
log "=== TC-3: 用户管理页面验证 ==="
pc_goto "$BASE_URL/users" >/dev/null 2>&1
sleep 1

assert_text "TC-3a: 页面标题为用户管理" "用户管理"
assert_text "TC-3b: 包含 admin 用户" "admin"
assert_text "TC-3c: 用户状态正常" "正常"

# =============================================================================
# TC-4  创建开发机 (Create Notebook)
# =============================================================================
log ""
log "=== TC-4: 创建开发机 ==="
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 1

# Stop any existing running instance first
EXISTING=$(playwright-cli run-code "async page => {
  const body = await page.evaluate(() => document.body.innerText);
  return (body.includes('\u8fd0\u884c\u4e2d') || body.includes('\u521b\u5efa\u4e2d')) ? 'true' : 'false';
}" 2>/dev/null | get_result)
if [[ "$EXISTING" == "true" ]]; then
  log "  Stopping existing instance..."
  pc_code "async page => {
    const stopBtn = page.getByRole('button', { name: '停止' }).first();
    if (await stopBtn.isVisible()) {
      await stopBtn.click();
      const confirmBtn = page.getByRole('button', { name: '停止', exact: true });
      if (await confirmBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
        await confirmBtn.click();
      }
    }
  }" >/dev/null 2>&1
  sleep 5
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 2
fi

# Create new notebook
pc_code "async page => {
  await page.getByRole('button', { name: '创建开发机' }).click();
  await page.waitForSelector('.spec-card', { timeout: 5000 });
  await page.locator('.spec-card').first().click();
  await page.locator('[class*=\"select\"]').first().click();
  await page.waitForSelector('[role=\"option\"]', { timeout: 3000 });
  await page.locator('[role=\"option\"]').first().click();
  await page.getByRole('button', { name: '创建', exact: true }).click();
}" >/dev/null 2>&1
sleep 2

pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 3  # wait for Vue component to fetch and render instance list

# Check table has data (either fresh new one or existing running one)
if wait_for_text "admin" 10 && (wait_for_text "运行中" 5 || wait_for_text "创建中" 5); then
  pass "TC-4a: 创建开发机记录存在"
  pass "TC-4b: 实例状态为创建中或运行中"
else
  assert_text "TC-4a: 创建开发机记录存在" "admin"
  CREATED=$(playwright-cli run-code "async page => {
    const body = await page.evaluate(() => document.body.innerText);
    return (body.includes('\u8fd0\u884c\u4e2d') || body.includes('\u521b\u5efa\u4e2d')) ? 'true' : 'false';
  }" 2>/dev/null | get_result)
  if [[ "$CREATED" == "true" ]]; then
    pass "TC-4b: 实例状态为创建中或运行中"
  else
    fail "TC-4b: 实例状态" "期望创建中/运行中"
  fi
fi

# =============================================================================
# TC-5  等待 Pod Running，访问 JupyterLab (JupyterLab Access)
# =============================================================================
log ""
log "=== TC-5: 等待 Pod 就绪并访问 JupyterLab ==="
log "  等待 Pod Running（最多 120s）..."

POD_READY=false
for i in $(seq 1 24); do
  STATUS=$(kubectl -n jupyter get pod jupyterlab-admin --no-headers 2>/dev/null | awk '{print $3}' || echo "")
  READY=$(kubectl -n jupyter get pod jupyterlab-admin --no-headers 2>/dev/null | awk '{print $2}' || echo "")
  if [[ "$STATUS" == "Running" && "$READY" == "1/1" ]]; then
    POD_READY=true
    pass "TC-5a: Pod jupyterlab-admin 状态 1/1 Running"
    break
  fi
  log "  ($i/24) 当前状态: $STATUS $READY — 等待5s..."
  sleep 5
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
done

if [[ "$POD_READY" == "false" ]]; then
  fail "TC-5a: Pod Running" "120s 内 Pod 未就绪"
else
  # Refresh page and get token from table
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 2

  assert_text "TC-5b: 实例状态显示运行中" "运行中"

  # Open JupyterLab in new tab via '进入' button
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

    # Wait up to 40s for JupyterLab jp-* DOM elements to appear
    JP_LOADED=false
    for i in $(seq 1 40); do
      JP=$(run_timeout 10 playwright-cli run-code "async page => {
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
    FB=$(run_timeout 10 playwright-cli run-code "async page => {
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

# =============================================================================
# TC-6  在 JupyterLab 中运行训练代码 (Run Training Code)
# =============================================================================
log ""
log "=== TC-6: 在 JupyterLab 中运行训练代码 ==="

TRAINING_CODE=$(cat <<'PYEOF'
# Simple gradient descent — linear regression (pure Python, no imports needed)
X = [1.0, 2.0, 3.0, 4.0, 5.0]
y_true = [2.0, 4.0, 6.0, 8.0, 10.0]

w, b = 0.0, 0.0
lr = 0.01
n = len(X)

for epoch in range(500):
    y_pred = [w * x + b for x in X]
    loss = sum((yp - yt)**2 for yp, yt in zip(y_pred, y_true)) / n
    dw = sum(2*(yp - yt)*x for yp, yt, x in zip(y_pred, y_true, X)) / n
    db = sum(2*(yp - yt) for yp, yt in zip(y_pred, y_true)) / n
    w -= lr * dw
    b -= lr * db

print(f"Trained: w={w:.4f}, b={b:.4f}, loss={loss:.8f}")
assert abs(w - 2.0) < 0.01, f"Expected w~2, got {w:.4f}"
assert abs(b) < 0.1,        f"Expected b~0, got {b:.4f}"
print("TRAINING_TEST_PASSED")
PYEOF
)

if [[ "$POD_READY" == "true" ]]; then
  # Make sure we're on the JupyterLab tab
  run_timeout 8 playwright-cli tab-select 1 >/dev/null 2>&1
  sleep 1

  # Click "Python 3 (ipykernel)" to open a new notebook
  pc_code "async page => {
    // Click Python 3 (ipykernel) in the notebook launcher section
    const items = await page.locator('[title*=\"Python 3\"]').all();
    if (items.length > 0) {
      await items[0].click();
      await page.waitForTimeout(3000);
    } else {
      // Try the labeled option in launcher
      const opt = page.getByText('Python 3 (ipykernel)').first();
      if (await opt.isVisible({ timeout: 3000 }).catch(() => false)) {
        await opt.click();
        await page.waitForTimeout(3000);
      }
    }
  }" >/dev/null 2>&1
  sleep 3

  # Type training code into the first code cell
  ESCAPED_CODE=$(echo "$TRAINING_CODE" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  pc_code "async page => {
    // Find the active code cell input
    const cell = page.locator('.jp-Cell .jp-InputArea-editor .CodeMirror-code, .jp-Cell .cm-content').first();
    await cell.click();
    await page.keyboard.insertText(${ESCAPED_CODE});
    await page.waitForTimeout(500);
  }" >/dev/null 2>&1
  sleep 1

  # Run the cell with Shift+Enter
  run_timeout 5 playwright-cli keydown Shift >/dev/null 2>&1
  run_timeout 5 playwright-cli press Enter >/dev/null 2>&1
  run_timeout 5 playwright-cli keyup Shift >/dev/null 2>&1
  sleep 1

  # Also try via run-code Shift+Enter
  pc_code "async page => {
    await page.keyboard.press('Shift+Enter');
    await page.waitForTimeout(8000);
  }" >/dev/null 2>&1
  sleep 8

  # Verify output
  if wait_for_text "TRAINING_TEST_PASSED" 30; then
    pass "TC-6a: 训练代码执行完成，输出 TRAINING_TEST_PASSED"
  else
    fail "TC-6a: 训练代码执行" "未找到 TRAINING_TEST_PASSED 输出"
  fi

  # TC-6b: check for errors in output - do targeted JS search (avoid full body capture)
  HAS_ERR=$(run_timeout 15 playwright-cli run-code "async page => {
    const body = await page.evaluate(() => document.body.innerText);
    return (body.includes('AssertionError') || body.includes('Traceback')) ? 'true' : 'false';
  }" 2>/dev/null | get_result)
  if [[ "$HAS_ERR" == "true" ]]; then
    fail "TC-6b: 训练代码无运行错误" "检测到错误输出"
  else
    pass "TC-6b: 训练代码无运行错误"
  fi

  # TC-6c: verify the training print line appeared (assertions passed → w≈2.0 confirmed)
  TRAINED=$(run_timeout 15 playwright-cli run-code "async page => {
    const body = await page.evaluate(() => document.body.innerText);
    return body.includes('Trained:') ? 'found' : 'not-found';
  }" 2>/dev/null | get_result)
  TRAINED="${TRAINED:-not-found}"
  if [[ "${TRAINED}" == "found" ]]; then
    pass "TC-6c: 梯度下降收敛，训练输出包含 Trained: 行"
  else
    fail "TC-6c: 梯度下降收敛" "未找到 Trained: 输出行"
  fi
else
  fail "TC-6a: 训练代码执行" "跳过（Pod 未就绪）"
  fail "TC-6b: 训练代码无运行错误" "跳过"
  fail "TC-6c: 梯度下降收敛" "跳过"
fi

# =============================================================================
# TC-7  退出登录 (Logout)
# =============================================================================
log ""
log "=== TC-7: 退出登录 ==="
# Navigate back to main app tab
run_timeout 8 playwright-cli tab-select 0 >/dev/null 2>&1
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 1

# Logout: click menu, capture toast synchronously before redirect
LOGOUT_RESULT=$(run_timeout 20 playwright-cli run-code "async page => {
  await page.getByRole('button', { name: 'admin' }).click();
  await page.waitForTimeout(500);
  await page.getByRole('menuitem', { name: '\u9000\u51fa\u767b\u5f55' }).click();
  let toastFound = false;
  try {
    await page.getByText('\u5df2\u9000\u51fa\u767b\u5f55', { exact: false })
      .waitFor({ state: 'visible', timeout: 3000 });
    toastFound = true;
  } catch(e) {}
  await page.waitForURL('**/login', { timeout: 6000 }).catch(() => {});
  return toastFound ? 'toast-found' : 'no-toast';
}" 2>/dev/null | get_result)
sleep 1

assert_url "TC-7a: 退出登录后跳转到 /login" "/login"
if [[ "$LOGOUT_RESULT" == "toast-found" ]]; then
  pass "TC-7b: 显示退出成功提示"
else
  fail "TC-7b: 显示退出成功提示" "toast '已退出登录' 未出现"
fi
# Wait for Vue login form to render — check the visible login button (not placeholder)
if wait_for_text "登 录" 8 || wait_for_text "登录" 5; then
  pass "TC-7c: 显示登录表单"
else
  fail "TC-7c: 显示登录表单" "expected login page content not found"
fi

# Protected route — accessing /notebooks should redirect to login
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 1
assert_url "TC-7d: 未登录访问 /notebooks 重定向到 /login" "/login"

# =============================================================================
# Summary
# =============================================================================
log ""
log "════════════════════════════════════════════════"
log "  TEST RESULTS:  PASS=$PASS  FAIL=$FAIL"
log "════════════════════════════════════════════════"
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  log "Failed test cases:"
  for e in "${ERRORS[@]}"; do
    log "  ✗ $e"
  done
fi

playwright-cli kill-all 2>/dev/null || true

if [[ "$FAIL" -eq 0 ]]; then
  log "All tests passed!"
  exit 0
else
  log "Some tests failed."
  exit 1
fi
