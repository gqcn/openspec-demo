#!/usr/bin/env bash
# TC-6  在 JupyterLab 中运行训练代码 (Run Training Code)
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

if [[ "${POD_READY:-false}" == "true" ]]; then
  # Make sure we're on the JupyterLab tab
  run_timeout 8 playwright-cli tab-select 1 >/dev/null 2>&1
  sleep 1

  # Click "Python 3 (ipykernel)" to open a new notebook
  pc_code "async page => {
    const items = await page.locator('[title*=\"Python 3\"]').all();
    if (items.length > 0) {
      await items[0].click();
      await page.waitForTimeout(3000);
    } else {
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
    const cell = page.locator('.jp-Cell .jp-InputArea-editor .CodeMirror-code, .jp-Cell .cm-content').first();
    await cell.click();
    await page.keyboard.insertText(${ESCAPED_CODE});
    await page.waitForTimeout(500);
  }" >/dev/null 2>&1
  sleep 1

  # Run the cell with Shift+Enter
  run_timeout "$TIMEOUT_MEDIUM" playwright-cli run-code "async page => {
    const cell = page.locator('.jp-Cell .jp-InputArea-editor .CodeMirror-code, .jp-Cell .cm-content').first();
    await cell.click().catch(() => {});
    await page.keyboard.press('Shift+Enter');
    await page.waitForTimeout(10000);
  }" >/dev/null 2>&1
  sleep 5

  # Verify output
  if wait_for_text "TRAINING_TEST_PASSED" 60; then
    pass "TC-6a: 训练代码执行完成，输出 TRAINING_TEST_PASSED"
  else
    fail "TC-6a: 训练代码执行" "未找到 TRAINING_TEST_PASSED 输出"
  fi

  # TC-6b: check for errors
  HAS_ERR=$(page_contains "AssertionError")
  HAS_TB=$(page_contains "Traceback")
  if [[ "$HAS_ERR" == "true" || "$HAS_TB" == "true" ]]; then
    fail "TC-6b: 训练代码无运行错误" "检测到错误输出"
  else
    pass "TC-6b: 训练代码无运行错误"
  fi

  # TC-6c: verify training print line
  TRAINED=$(page_contains "Trained:")
  if [[ "${TRAINED:-}" == "true" ]]; then
    pass "TC-6c: 梯度下降收敛，训练输出包含 Trained: 行"
  else
    fail "TC-6c: 梯度下降收敛" "未找到 Trained: 输出行"
  fi
else
  fail "TC-6a: 训练代码执行" "跳过（Pod 未就绪）"
  fail "TC-6b: 训练代码无运行错误" "跳过"
  fail "TC-6c: 梯度下降收敛" "跳过"
fi
