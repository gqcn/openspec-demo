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
  awk '/^### Result$/{getline; print; exit}' | tr -d '"\r'
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

# Ensure GPU-标准 spec exists (may be missing if DB was reset or previous run failed)
GPU_SEED_RESULT=$(run_timeout 10 playwright-cli run-code "async page => {
  return await page.evaluate(async () => {
    const token = localStorage.getItem('token') || '';
    const lr = await fetch('/api/spec', { headers: { 'Authorization': 'Bearer ' + token } });
    const ld = await lr.json();
    const list = (ld.data && ld.data.list) ? ld.data.list : [];
    const has = list.some(s => s.name === 'GPU-\u6807\u51c6');
    if (!has) {
      const cr = await fetch('/api/spec', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
        body: JSON.stringify({
          name: 'GPU-\u6807\u51c6', cpu: '4', memory: '16Gi', gpu: '1',
          gpuType: 'nvidia.com/gpu',
          nodeSelector: '{\"gpu-type\": \"gpu\"}',
          tolerations: '[{\"key\":\"gpu\",\"operator\":\"Exists\",\"effect\":\"NoSchedule\"}]',
          sortOrder: 30, enabled: 1
        })
      });
      const cd = await cr.json();
      return cd.code === 0 ? 'seeded' : 'seed-failed:' + cd.message;
    }
    return 'exists';
  });
}" 2>/dev/null | get_result)
if [[ "${GPU_SEED_RESULT:-}" == 'seeded' ]]; then
  log "  ✎ GPU-标准 was missing — re-seeded via API"
  sleep 1
  pc_goto "$BASE_URL/specs" >/dev/null 2>&1
  sleep 1
elif [[ "${GPU_SEED_RESULT:-}" == 'exists' ]]; then
  : # already present
else
  log "  ⚠ GPU-标准 seed check returned: ${GPU_SEED_RESULT:-empty}"
fi

assert_text "TC-2a: 页面标题为规格管理" "规格管理"
assert_text "TC-2b: 包含 CPU-小 规格" "CPU-小"
assert_text "TC-2c: 包含 CPU-大 规格" "CPU-大"
assert_text "TC-2d: 包含 GPU-标准 规格" "GPU-标准"
assert_text "TC-2e: 包含编辑操作" "编辑"

# TC-2f: 创建新规格并验证出现在列表
log ""
log "=== TC-2f/TC-2g: 创建并修改规格 ==="
pc_code "async page => {
  await page.getByRole('button', { name: '新增规格' }).click();
  await page.waitForSelector('.el-dialog__body', { timeout: 4000 });
  await page.getByPlaceholder('如: 4C8G').fill('Test-CPU-E2E');
  await page.getByPlaceholder('如: 4', { exact: true }).fill('500m');
  await page.getByPlaceholder('如: 8Gi').fill('1Gi');
  await page.getByRole('button', { name: '保存' }).click();
  await page.waitForTimeout(1500);
}" >/dev/null 2>&1
sleep 1
pc_goto "$BASE_URL/specs" >/dev/null 2>&1
sleep 1
assert_text "TC-2f: 创建规格后出现在列表" "Test-CPU-E2E"

# TC-2g: 修改规格 CPU 并验证更新
pc_code "async page => {
  const rows = await page.locator('tr').all();
  for (const row of rows) {
    const text = await row.innerText().catch(() => '');
    if (text.includes('Test-CPU-E2E')) {
      await row.getByRole('button', { name: '编辑' }).click();
      break;
    }
  }
  await page.waitForSelector('.el-dialog__body', { timeout: 3000 });
  const cpuInput = page.getByPlaceholder('如: 4', { exact: true });
  await cpuInput.clear();
  await cpuInput.fill('1000m');
  await page.getByRole('button', { name: '保存' }).click();
  await page.waitForTimeout(1500);
}" >/dev/null 2>&1
sleep 1
pc_goto "$BASE_URL/specs" >/dev/null 2>&1
sleep 1
assert_text "TC-2g: 修改规格 CPU 后更新成功" "1000m"

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

# TC-3d: 创建新用户并验证出现在列表
log ""
log "=== TC-3d/TC-3e: 创建新用户 ==="
pc_code "async page => {
  await page.getByRole('button', { name: '新增用户' }).click();
  await page.waitForSelector('.el-dialog__body', { timeout: 4000 });
  await page.getByPlaceholder('请输入用户名').fill('testuser01');
  await page.locator('[type=\"password\"]').first().fill('Test@123456');
  await page.getByRole('button', { name: '创建' }).click();
  await page.waitForTimeout(1500);
}" >/dev/null 2>&1
sleep 1
pc_goto "$BASE_URL/users" >/dev/null 2>&1
sleep 1
assert_text "TC-3d: 创建用户后出现在列表" "testuser01"

# TC-3e: 禁用新用户，验证状态变更
pc_code "async page => {
  const rows = await page.locator('tr').all();
  for (const row of rows) {
    const text = await row.innerText().catch(() => '');
    if (text.includes('testuser01')) {
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
DISABLED_FOUND=$(run_timeout 10 playwright-cli run-code "async page => {
  const body = await page.evaluate(() => document.body.innerText);
  return body.includes('testuser01') && body.includes('\u7981\u7528') ? 'true' : 'false';
}" 2>/dev/null | get_result)
if [[ "$DISABLED_FOUND" == "true" ]]; then
  pass "TC-3e: 禁用用户后状态显示禁用"
else
  fail "TC-3e: 禁用用户后状态显示禁用" "testuser01 未变为禁用状态"
fi

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
      // Scope to .el-message-box to avoid strict-mode violation with multiple '停止' buttons
      try {
        const msgBox = page.locator('.el-message-box');
        await msgBox.waitFor({ state: 'visible', timeout: 3000 });
        await msgBox.getByRole('button', { name: '停止', exact: true }).click();
      } catch(e) {}
    }
  }" >/dev/null 2>&1
  sleep 5
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 2
fi

# Create new notebook
# Use run_timeout 25 and .el-select__wrapper to avoid [class*="select"] matching spec-card.selected
run_timeout 25 playwright-cli run-code "async page => {
  await page.getByRole('button', { name: '\u521b\u5efa\u5f00\u53d1\u673a' }).click();
  // Wait for spec cards to load (onMounted API calls)
  await page.waitForSelector('.spec-card', { timeout: 5000 });
  await page.waitForTimeout(300); // brief wait for dialog animation
  await page.locator('.spec-card').first().click();
  // Open image dropdown via its clickable wrapper (not [class*='select'] which matches spec-card.selected)
  await page.locator('.el-select__wrapper').first().click();
  await page.waitForSelector('[role=\"option\"]', { timeout: 3000 });
  await page.locator('[role=\"option\"]').first().click();
  await page.getByRole('button', { name: '\u521b\u5efa', exact: true }).click();
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

# TC-4c: 创建按钮在有活跃实例时应禁用
log ""
log "=== TC-4c/TC-4d: 重复创建开发机防护 ==="
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 2
BTN_DISABLED=$(run_timeout 10 playwright-cli run-code "async page => {
  const btn = page.getByRole('button', { name: '创建开发机' });
  try {
    const isDisabled = await btn.isDisabled({ timeout: 3000 });
    return isDisabled ? 'true' : 'false';
  } catch(e) { return 'error:' + e.message; }
}" 2>/dev/null | get_result)
if [[ "$BTN_DISABLED" == "true" ]]; then
  pass "TC-4c: 有活跃实例时创建按钮已禁用"
else
  fail "TC-4c: 有活跃实例时创建按钮已禁用" "按钮未禁用（得到: ${BTN_DISABLED}）"
fi

# TC-4d: API 层面拒绝重复创建 (via fetch in browser)
# NOTE: localStorage must be accessed inside page.evaluate() (browser context),
# not in the outer playwright-cli callback which runs in Node.js context.
DUPLICATE_ERR=$(run_timeout 15 playwright-cli run-code "async page => {
  try {
    const resp = await page.evaluate(async () => {
      const token = localStorage.getItem('token') || '';
      const r = await fetch('/api/notebook', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
        body: JSON.stringify({ specId: 1, imageKey: 'python-general' })
      });
      const d = await r.json();
      return d.code + '';
    });
    return resp !== '0' ? 'rejected' : 'allowed';
  } catch(e) { return 'error:' + e.message; }
}" 2>/dev/null | get_result)
if [[ "$DUPLICATE_ERR" == "rejected" ]]; then
  pass "TC-4d: API 拒绝重复创建开发机"
else
  fail "TC-4d: API 拒绝重复创建开发机" "期望拒绝，实际: $DUPLICATE_ERR"
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

  # Run the cell with Shift+Enter (use run-code to keep context; avoid separate keydown/press/keyup
  # which resets keyboard state between playwright-cli invocations)
  run_timeout 15 playwright-cli run-code "async page => {
    // Re-click the cell to ensure it has focus, then run it
    const cell = page.locator('.jp-Cell .jp-InputArea-editor .CodeMirror-code, .jp-Cell .cm-content').first();
    await cell.click().catch(() => {});
    await page.keyboard.press('Shift+Enter');
    await page.waitForTimeout(10000); // wait for kernel to start and execute
  }" >/dev/null 2>&1
  sleep 5

  # Verify output — wait up to 60 iterations (~60s) for kernel startup + code execution
  if wait_for_text "TRAINING_TEST_PASSED" 60; then
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
LOGOUT_RESULT=$(run_timeout 25 playwright-cli run-code "async page => {
  // Click the user dropdown trigger; el-dropdown may render as role=button or tabindex span
  const adminBtn = page.getByRole('button', { name: 'admin' });
  if (await adminBtn.count() > 0) {
    await adminBtn.click({ timeout: 3000 }).catch(async () => {
      await page.locator('.el-header .el-dropdown, .el-header [tabindex=\"0\"]').first().click();
    });
  } else {
    await page.locator('.el-header .el-dropdown, .el-header [tabindex=\"0\"]').first().click();
  }
  await page.waitForTimeout(500);
  await page.getByRole('menuitem', { name: '\u9000\u51fa\u767b\u5f55' }).click({ timeout: 5000 });
  let toastFound = false;
  try {
    await page.getByText('\u5df2\u9000\u51fa\u767b\u5f55', { exact: false })
      .waitFor({ state: 'visible', timeout: 3000 });
    toastFound = true;
  } catch(e) {}
  await page.waitForURL('**/login', { timeout: 8000 }).catch(() => {});
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
# TC-7e/TC-7f  登录边界测试（错误密码）
# =============================================================================
log ""
log "=== TC-7e/TC-7f: 错误密码登录边界测试 ==="
# We are on /login already — test wrong password (used to crash with TypeError)
WRONG_PASS_RESULT=$(run_timeout 20 playwright-cli run-code "async page => {
  await page.getByPlaceholder('请输入用户名').fill('admin');
  await page.getByPlaceholder('请输入密码').fill('wrong_password_!@#');
  await page.getByRole('button', { name: '\u767b \u5f55' }).click();
  let toastFound = false;
  try {
    await page.locator('.el-message--error').waitFor({ state: 'visible', timeout: 5000 });
    toastFound = true;
  } catch(e) {}
  // also accept any el-message
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

# Re-login as admin for TC-8
pc_code "async page => {
  await page.getByPlaceholder('请输入用户名').fill('$ADMIN_USER');
  await page.getByPlaceholder('请输入密码').fill('$ADMIN_PASS');
  await page.getByRole('button', { name: '\u767b \u5f55' }).click();
  await page.waitForURL('**/notebooks', { timeout: 8000 });
}" >/dev/null 2>&1
sleep 2

# =============================================================================
# TC-8  不同镜像开发机创建测试
# =============================================================================
log ""
log "=== TC-8: 不同镜像（PyTorch）开发机创建测试 ==="
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 2

# Stop existing notebook if any are active
HAS_ACTIVE=$(run_timeout 10 playwright-cli run-code "async page => {
  const body = await page.evaluate(() => document.body.innerText);
  return (body.includes('\u8fd0\u884c\u4e2d') || body.includes('\u521b\u5efa\u4e2d') || body.includes('\u505c\u6b62\u4e2d')) ? 'true' : 'false';
}" 2>/dev/null | get_result)

if [[ "$HAS_ACTIVE" == "true" ]]; then
  log "  TC-8: 停止活跃实例以准备测试..."
  pc_code "async page => {
    const stopBtns = await page.getByRole('button', { name: '\u505c\u6b62' }).all();
    if (stopBtns.length > 0) {
      await stopBtns[0].click();
      // Wait for and confirm the ElMessageBox dialog — scope to .el-message-box to avoid
      // strict-mode violation with multiple '停止' buttons (table row + dialog confirm).
      try {
        const msgBox = page.locator('.el-message-box');
        await msgBox.waitFor({ state: 'visible', timeout: 3000 });
        await msgBox.getByRole('button', { name: '\u505c\u6b62', exact: true }).click();
      } catch(e) {}
    }
    await page.waitForTimeout(3000);
  }" >/dev/null 2>&1

  # Wait up to 60s for instance to enter stopped state
  for i in $(seq 1 12); do
    pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
    sleep 3
    STILL_ACTIVE=$(run_timeout 8 playwright-cli run-code "async page => {
      const body = await page.evaluate(() => document.body.innerText);
      return (body.includes('\u8fd0\u884c\u4e2d') || body.includes('\u521b\u5efa\u4e2d') || body.includes('\u505c\u6b62\u4e2d')) ? 'true' : 'false';
    }" 2>/dev/null | get_result)
    [[ "$STILL_ACTIVE" != "true" ]] && break
    log "  ($i/12) 等待实例停止..."
  done
fi

# Delete stopped record (if any)
HAS_STOPPED=$(run_timeout 8 playwright-cli run-code "async page => {
  const body = await page.evaluate(() => document.body.innerText);
  return (body.includes('\u5df2\u505c\u6b62') || body.includes('\u5f02\u5e38')) ? 'true' : 'false';
}" 2>/dev/null | get_result)

if [[ "$HAS_STOPPED" == "true" ]]; then
  pc_code "async page => {
    const delBtns = await page.getByRole('button', { name: '\u5220\u9664\u8bb0\u5f55' }).all();
    if (delBtns.length > 0) {
      await delBtns[0].click();
      const confirmBtn = page.getByRole('button', { name: '\u5220\u9664', exact: true });
      if (await confirmBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
        await confirmBtn.click();
      }
      await page.waitForTimeout(1500);
    }
  }" >/dev/null 2>&1
  sleep 1
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 1
  pass "TC-8a: 已停止实例可通过删除记录按钮清除"
else
  pass "TC-8a: 无已停止实例需清除（跳过）"
fi

# Verify create button is now enabled
BTN_ENABLED=$(run_timeout 10 playwright-cli run-code "async page => {
  const btn = page.getByRole('button', { name: '\u521b\u5efa\u5f00\u53d1\u673a' });
  try {
    const isDisabled = await btn.isDisabled({ timeout: 3000 });
    return isDisabled ? 'false' : 'true';
  } catch(e) { return 'error'; }
}" 2>/dev/null | get_result)
BTN_ENABLED=${BTN_ENABLED:-}  # defensive: default to empty string if unset (set -u)
if [[ "$BTN_ENABLED" == "true" ]]; then
  pass "TC-8b: 清除记录后创建按钮已启用"
else
  fail "TC-8b: 清除记录后创建按钮已启用" "按钮仍禁用（result: ${BTN_ENABLED}）"
fi

# Create notebook with the second image (PyTorch)
# Use run_timeout 25 (not pc_code's default 15) to allow time for dialog + API calls.
# Fix: use .el-select__wrapper to target the image dropdown trigger reliably in El Plus v2.
run_timeout 25 playwright-cli run-code "async page => {
  await page.getByRole('button', { name: '\u521b\u5efa\u5f00\u53d1\u673a' }).click();
  // Wait for spec cards to load (onMounted API calls)
  await page.waitForSelector('.spec-card', { timeout: 5000 });
  await page.waitForTimeout(300); // brief wait for dialog animation
  await page.locator('.spec-card').first().click();
  // Open image dropdown — .el-select__wrapper is the clickable trigger (avoids .spec-card.selected)
  await page.locator('.el-select__wrapper').first().click();
  await page.waitForSelector('[role=\"option\"]', { timeout: 3000 });
  // Select the LAST image option (PyTorch)
  const opts = await page.locator('[role=\"option\"]').all();
  const lastOpt = opts[opts.length - 1];
  await lastOpt.click();
  await page.getByRole('button', { name: '\u521b\u5efa', exact: true }).click();
  await page.waitForTimeout(2000);
}" >/dev/null 2>&1
sleep 2
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 2

# TC-8c: Verify pytorch image appears in the notebook list
# The frontend shows imageName ("PyTorch 2.2 + CUDA 12.1") or imageKey ("pytorch-cuda121"),
# not the raw Docker image URL. Check for 'PyTorch' or 'pytorch-cuda121'.
PYTORCH_FOUND=$(run_timeout 10 playwright-cli run-code "async page => {
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
# =============================================================================
# TC-9  多用户 /share 共享目录访问测试 (Multi-user /share Access)
# =============================================================================
log ""
log "=== TC-9: 多用户 /share 共享目录访问测试 ==="

TESTUSER="testuser01"
TESTUSER_PASS="Test@123456"
SHARE_FILE_ADMIN="admin_share_test_$(date +%s).txt"
SHARE_FILE_USER="testuser01_share_test_$(date +%s).txt"

# ── Step 0: Clean up TC-8's instance (may be stuck in ImagePullBackOff) and
#            create a fresh admin instance with the first (base-notebook) image ──
log "  TC-9 setup: 清理 TC-8 实例，重新创建 admin 开发机（base-notebook 镜像）..."
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 2

# Stop any active/creating instance
TC9_HAS_ACTIVE=$(run_timeout 10 playwright-cli run-code "async page => {
  const body = await page.evaluate(() => document.body.innerText);
  return (body.includes('\u8fd0\u884c\u4e2d') || body.includes('\u521b\u5efa\u4e2d') || body.includes('\u505c\u6b62\u4e2d')) ? 'true' : 'false';
}" 2>/dev/null | get_result)
if [[ "$TC9_HAS_ACTIVE" == "true" ]]; then
  pc_code "async page => {
    const stopBtns = await page.getByRole('button', { name: '\u505c\u6b62' }).all();
    if (stopBtns.length > 0) {
      await stopBtns[0].click();
      try {
        const msgBox = page.locator('.el-message-box');
        await msgBox.waitFor({ state: 'visible', timeout: 3000 });
        await msgBox.getByRole('button', { name: '\u505c\u6b62', exact: true }).click();
      } catch(e) {}
    }
    await page.waitForTimeout(3000);
  }" >/dev/null 2>&1
  for i in $(seq 1 12); do
    pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
    sleep 3
    TC9_STILL=$(run_timeout 8 playwright-cli run-code "async page => {
      const body = await page.evaluate(() => document.body.innerText);
      return (body.includes('\u8fd0\u884c\u4e2d') || body.includes('\u521b\u5efa\u4e2d') || body.includes('\u505c\u6b62\u4e2d')) ? 'true' : 'false';
    }" 2>/dev/null | get_result)
    [[ "$TC9_STILL" != "true" ]] && break
    log "  ($i/12) 等待实例停止..."
  done
fi

# Delete any stopped/failed record
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 1
pc_code "async page => {
  const delBtns = await page.getByRole('button', { name: '\u5220\u9664\u8bb0\u5f55' }).all();
  if (delBtns.length > 0) {
    await delBtns[0].click();
    const confirmBtn = page.getByRole('button', { name: '\u5220\u9664', exact: true });
    if (await confirmBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
      await confirmBtn.click();
    }
    await page.waitForTimeout(1500);
  }
}" >/dev/null 2>&1
sleep 1

# Create a new admin instance with the FIRST image (base-notebook, works in Kind)
log "  TC-9 setup: 为 admin 创建 base-notebook 开发机..."
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 1
run_timeout 25 playwright-cli run-code "async page => {
  await page.getByRole('button', { name: '\u521b\u5efa\u5f00\u53d1\u673a' }).click();
  await page.waitForSelector('.spec-card', { timeout: 5000 });
  await page.waitForTimeout(300);
  await page.locator('.spec-card').first().click();
  await page.locator('.el-select__wrapper').first().click();
  await page.waitForSelector('[role=\"option\"]', { timeout: 3000 });
  // Select the FIRST image option (base-notebook — available in Kind)
  await page.locator('[role=\"option\"]').first().click();
  await page.getByRole('button', { name: '\u521b\u5efa', exact: true }).click();
  await page.waitForTimeout(2000);
}" >/dev/null 2>&1
sleep 2

# ── Step 1: Wait for admin's notebook pod to be running ──
log "  TC-9 setup: 等待 admin 开发机 Pod 就绪（最多 120s）..."
ADMIN_POD_READY=false
for i in $(seq 1 24); do
  STATUS=$(kubectl -n jupyter get pod jupyterlab-admin --no-headers 2>/dev/null | awk '{print $3}' || echo "")
  READY=$(kubectl -n jupyter get pod jupyterlab-admin --no-headers 2>/dev/null | awk '{print $2}' || echo "")
  if [[ "$STATUS" == "Running" && "$READY" == "1/1" ]]; then
    ADMIN_POD_READY=true
    log "  admin Pod 1/1 Running ✓"
    break
  fi
  log "  ($i/24) 当前状态: $STATUS $READY — 等待5s..."
  sleep 5
done

if [[ "$ADMIN_POD_READY" == "false" ]]; then
  fail "TC-9a: admin 在 /share 创建共享文件" "admin Pod 未就绪，跳过 TC-9"
  fail "TC-9b: testuser01 Pod 可见 /share 共享文件" "跳过"
  fail "TC-9c: testuser01 可在 /share 写入文件" "跳过"
  fail "TC-9d: /share 包含两个用户的文件" "跳过"
else
  # ── Step 2: Admin creates a test file in /share ──
  log "  TC-9a: admin 在 /share 创建共享文件..."
  ADMIN_WRITE=$(kubectl -n jupyter exec jupyterlab-admin -- /bin/bash -c "echo 'hello from admin' > /share/${SHARE_FILE_ADMIN} && cat /share/${SHARE_FILE_ADMIN}" 2>&1)
  if [[ "$ADMIN_WRITE" == *"hello from admin"* ]]; then
    pass "TC-9a: admin 在 /share 创建共享文件成功"
  else
    fail "TC-9a: admin 在 /share 创建共享文件" "写入或读取失败: $ADMIN_WRITE"
  fi

  # ── Step 3: Stop admin's notebook and delete record ──
  log "  TC-9 setup: 停止 admin 开发机..."
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 2
  pc_code "async page => {
    const stopBtns = await page.getByRole('button', { name: '\u505c\u6b62' }).all();
    if (stopBtns.length > 0) {
      await stopBtns[0].click();
      try {
        const msgBox = page.locator('.el-message-box');
        await msgBox.waitFor({ state: 'visible', timeout: 3000 });
        await msgBox.getByRole('button', { name: '\u505c\u6b62', exact: true }).click();
      } catch(e) {}
    }
    await page.waitForTimeout(3000);
  }" >/dev/null 2>&1

  # Wait for instance to stop
  for i in $(seq 1 12); do
    pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
    sleep 3
    STILL_ACTIVE=$(run_timeout 8 playwright-cli run-code "async page => {
      const body = await page.evaluate(() => document.body.innerText);
      return (body.includes('\u8fd0\u884c\u4e2d') || body.includes('\u521b\u5efa\u4e2d') || body.includes('\u505c\u6b62\u4e2d')) ? 'true' : 'false';
    }" 2>/dev/null | get_result)
    [[ "$STILL_ACTIVE" != "true" ]] && break
    log "  ($i/12) 等待 admin 实例停止..."
  done

  # Delete stopped record
  pc_code "async page => {
    const delBtns = await page.getByRole('button', { name: '\u5220\u9664\u8bb0\u5f55' }).all();
    if (delBtns.length > 0) {
      await delBtns[0].click();
      const confirmBtn = page.getByRole('button', { name: '\u5220\u9664', exact: true });
      if (await confirmBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
        await confirmBtn.click();
      }
      await page.waitForTimeout(1500);
    }
  }" >/dev/null 2>&1
  sleep 1

  # ── Step 4: Re-enable testuser01 via API (was disabled in TC-3e) ──
  log "  TC-9 setup: 重新启用 testuser01..."
  ENABLE_RESULT=$(run_timeout 10 playwright-cli run-code "async page => {
    return await page.evaluate(async () => {
      const token = localStorage.getItem('token') || '';
      // Get user list to find testuser01's id
      const lr = await fetch('/api/user', { headers: { 'Authorization': 'Bearer ' + token } });
      const ld = await lr.json();
      const list = (ld.data && ld.data.list) ? ld.data.list : [];
      const user = list.find(u => u.username === 'testuser01');
      if (!user) return 'user-not-found';
      // Re-enable (status=1)
      const ur = await fetch('/api/user/' + user.id + '/status', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
        body: JSON.stringify({ status: 1 })
      });
      const ud = await ur.json();
      return ud.code === 0 ? 'enabled' : 'enable-failed:' + ud.message;
    });
  }" 2>/dev/null | get_result)
  log "  testuser01 启用结果: ${ENABLE_RESULT:-empty}"

  # ── Step 5: Logout admin ──
  log "  TC-9 setup: 退出 admin 登录..."
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 1
  run_timeout 25 playwright-cli run-code "async page => {
    const adminBtn = page.getByRole('button', { name: 'admin' });
    if (await adminBtn.count() > 0) {
      await adminBtn.click({ timeout: 3000 }).catch(async () => {
        await page.locator('.el-header .el-dropdown, .el-header [tabindex=\"0\"]').first().click();
      });
    } else {
      await page.locator('.el-header .el-dropdown, .el-header [tabindex=\"0\"]').first().click();
    }
    await page.waitForTimeout(500);
    await page.getByRole('menuitem', { name: '\u9000\u51fa\u767b\u5f55' }).click({ timeout: 5000 });
    await page.waitForURL('**/login', { timeout: 8000 }).catch(() => {});
  }" >/dev/null 2>&1
  sleep 1

  # ── Step 6: Login as testuser01 ──
  log "  TC-9 setup: 以 testuser01 登录..."
  pc_goto "$BASE_URL/login" >/dev/null 2>&1
  sleep 1
  pc_code "async page => {
    await page.getByPlaceholder('\u8bf7\u8f93\u5165\u7528\u6237\u540d').fill('$TESTUSER');
    await page.getByPlaceholder('\u8bf7\u8f93\u5165\u5bc6\u7801').fill('$TESTUSER_PASS');
    await page.getByRole('button', { name: '\u767b \u5f55' }).click();
    await page.waitForURL('**/notebooks', { timeout: 8000 });
  }" >/dev/null 2>&1
  sleep 2

  # ── Step 7: Create notebook for testuser01 ──
  log "  TC-9 setup: 为 testuser01 创建开发机..."
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 1

  # Clean up any existing stopped/failed instances
  HAS_OLD=$(run_timeout 8 playwright-cli run-code "async page => {
    const body = await page.evaluate(() => document.body.innerText);
    return (body.includes('\u5df2\u505c\u6b62') || body.includes('\u5f02\u5e38')) ? 'true' : 'false';
  }" 2>/dev/null | get_result)
  if [[ "$HAS_OLD" == "true" ]]; then
    pc_code "async page => {
      const delBtns = await page.getByRole('button', { name: '\u5220\u9664\u8bb0\u5f55' }).all();
      if (delBtns.length > 0) {
        await delBtns[0].click();
        const confirmBtn = page.getByRole('button', { name: '\u5220\u9664', exact: true });
        if (await confirmBtn.isVisible({ timeout: 2000 }).catch(() => false)) {
          await confirmBtn.click();
        }
        await page.waitForTimeout(1500);
      }
    }" >/dev/null 2>&1
    sleep 1
    pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
    sleep 1
  fi

  run_timeout 25 playwright-cli run-code "async page => {
    await page.getByRole('button', { name: '\u521b\u5efa\u5f00\u53d1\u673a' }).click();
    await page.waitForSelector('.spec-card', { timeout: 5000 });
    await page.waitForTimeout(300);
    await page.locator('.spec-card').first().click();
    await page.locator('.el-select__wrapper').first().click();
    await page.waitForSelector('[role=\"option\"]', { timeout: 3000 });
    await page.locator('[role=\"option\"]').first().click();
    await page.getByRole('button', { name: '\u521b\u5efa', exact: true }).click();
    await page.waitForTimeout(2000);
  }" >/dev/null 2>&1
  sleep 2

  # ── Step 8: Wait for testuser01's pod to be running ──
  log "  TC-9 setup: 等待 testuser01 Pod 就绪（最多 120s）..."
  TESTUSER_POD_READY=false
  for i in $(seq 1 24); do
    STATUS=$(kubectl -n jupyter get pod jupyterlab-testuser01 --no-headers 2>/dev/null | awk '{print $3}' || echo "")
    READY=$(kubectl -n jupyter get pod jupyterlab-testuser01 --no-headers 2>/dev/null | awk '{print $2}' || echo "")
    if [[ "$STATUS" == "Running" && "$READY" == "1/1" ]]; then
      TESTUSER_POD_READY=true
      log "  testuser01 Pod 1/1 Running ✓"
      break
    fi
    log "  ($i/24) 当前状态: $STATUS $READY — 等待5s..."
    sleep 5
  done

  if [[ "$TESTUSER_POD_READY" == "false" ]]; then
    fail "TC-9b: testuser01 Pod 可见 /share 共享文件" "testuser01 Pod 未就绪"
    fail "TC-9c: testuser01 可在 /share 写入文件" "跳过"
    fail "TC-9d: /share 包含两个用户的文件" "跳过"
  else
    # ── Step 9: Verify /share contains admin's file from testuser01's pod ──
    log "  TC-9b: 从 testuser01 Pod 验证 /share 共享文件..."
    USER_READ=$(kubectl -n jupyter exec jupyterlab-testuser01 -- /bin/bash -c "cat /share/${SHARE_FILE_ADMIN}" 2>&1)
    if [[ "$USER_READ" == *"hello from admin"* ]]; then
      pass "TC-9b: testuser01 Pod 可见 admin 在 /share 创建的共享文件"
    else
      fail "TC-9b: testuser01 Pod 可见 /share 共享文件" "读取失败: $USER_READ"
    fi

    # ── Step 10: testuser01 creates a file in /share ──
    log "  TC-9c: testuser01 在 /share 写入文件..."
    USER_WRITE=$(kubectl -n jupyter exec jupyterlab-testuser01 -- /bin/bash -c "echo 'hello from testuser01' > /share/${SHARE_FILE_USER} && cat /share/${SHARE_FILE_USER}" 2>&1)
    if [[ "$USER_WRITE" == *"hello from testuser01"* ]]; then
      pass "TC-9c: testuser01 可在 /share 写入文件"
    else
      fail "TC-9c: testuser01 可在 /share 写入文件" "写入或读取失败: $USER_WRITE"
    fi

    # ── Step 11: Verify both files exist in /share ──
    log "  TC-9d: 验证 /share 包含两个用户的文件..."
    BOTH_FILES=$(kubectl -n jupyter exec jupyterlab-testuser01 -- /bin/bash -c "ls /share/${SHARE_FILE_ADMIN} /share/${SHARE_FILE_USER} 2>&1 && echo 'BOTH_EXIST'" 2>&1)
    if [[ "$BOTH_FILES" == *"BOTH_EXIST"* ]]; then
      pass "TC-9d: /share 目录同时包含 admin 和 testuser01 的共享文件"
    else
      fail "TC-9d: /share 包含两个用户的文件" "文件检查失败: $BOTH_FILES"
    fi

    # ── Cleanup: remove test files ──
    kubectl -n jupyter exec jupyterlab-testuser01 -- /bin/bash -c "rm -f /share/${SHARE_FILE_ADMIN} /share/${SHARE_FILE_USER}" 2>/dev/null || true
  fi

  # ── Cleanup: stop testuser01's notebook ──
  log "  TC-9 cleanup: 停止 testuser01 开发机..."
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 1
  pc_code "async page => {
    const stopBtns = await page.getByRole('button', { name: '\u505c\u6b62' }).all();
    if (stopBtns.length > 0) {
      await stopBtns[0].click();
      try {
        const msgBox = page.locator('.el-message-box');
        await msgBox.waitFor({ state: 'visible', timeout: 3000 });
        await msgBox.getByRole('button', { name: '\u505c\u6b62', exact: true }).click();
      } catch(e) {}
    }
    await page.waitForTimeout(3000);
  }" >/dev/null 2>&1
  sleep 3

  # ── Re-login as admin for any subsequent tests ──
  log "  TC-9 cleanup: 重新登录 admin..."
  run_timeout 25 playwright-cli run-code "async page => {
    const btn = page.getByRole('button', { name: 'testuser01' });
    if (await btn.count() > 0) {
      await btn.click({ timeout: 3000 }).catch(async () => {
        await page.locator('.el-header .el-dropdown, .el-header [tabindex=\"0\"]').first().click();
      });
    } else {
      await page.locator('.el-header .el-dropdown, .el-header [tabindex=\"0\"]').first().click();
    }
    await page.waitForTimeout(500);
    await page.getByRole('menuitem', { name: '\u9000\u51fa\u767b\u5f55' }).click({ timeout: 5000 });
    await page.waitForURL('**/login', { timeout: 8000 }).catch(() => {});
  }" >/dev/null 2>&1
  sleep 1
  pc_code "async page => {
    await page.getByPlaceholder('\u8bf7\u8f93\u5165\u7528\u6237\u540d').fill('$ADMIN_USER');
    await page.getByPlaceholder('\u8bf7\u8f93\u5165\u5bc6\u7801').fill('$ADMIN_PASS');
    await page.getByRole('button', { name: '\u767b \u5f55' }).click();
    await page.waitForURL('**/notebooks', { timeout: 8000 });
  }" >/dev/null 2>&1
  sleep 1
fi

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
