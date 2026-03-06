#!/usr/bin/env bash
# TC-4  创建开发机 (Create Notebook)
log ""
log "=== TC-4: 创建开发机 ==="
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 1

# Stop any existing running instance first
if has_active_notebook; then
  log "  Stopping existing instance..."
  do_stop_notebook
  sleep 5
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 2
fi

# Create new notebook (first image)
do_create_notebook 0
pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
sleep 3

# Check table has data
if wait_for_text "admin" 10 && (wait_for_text "运行中" 5 || wait_for_text "创建中" 5); then
  pass "TC-4a: 创建开发机记录存在"
  pass "TC-4b: 实例状态为创建中或运行中"
else
  assert_text "TC-4a: 创建开发机记录存在" "admin"
  if [[ "$(page_contains '运行中')" == "true" ]] || [[ "$(page_contains '创建中')" == "true" ]]; then
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
BTN_DISABLED=$(run_timeout "$TIMEOUT_SHORT" playwright-cli run-code "async page => {
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

# TC-4d: API 层面拒绝重复创建
DUPLICATE_ERR=$(browser_api "
  const r = await fetch('/api/notebook', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
    body: JSON.stringify({ specId: 1, imageKey: 'python-general' })
  });
  const d = await r.json();
  return d.code + '';
")
DUPLICATE_ERR="${DUPLICATE_ERR:-}"
if [[ "$DUPLICATE_ERR" != "0" && -n "$DUPLICATE_ERR" ]]; then
  pass "TC-4d: API 拒绝重复创建开发机"
else
  fail "TC-4d: API 拒绝重复创建开发机" "期望拒绝，实际: $DUPLICATE_ERR"
fi
