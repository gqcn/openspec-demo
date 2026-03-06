#!/usr/bin/env bash
# TC-2  规格管理页面验证 (Spec Management)
log ""
log "=== TC-2: 规格管理页面验证 ==="
pc_goto "$BASE_URL/specs" >/dev/null 2>&1
sleep 1

# Ensure GPU-标准 spec exists (may be missing if DB was reset)
GPU_SEED_RESULT=$(browser_api "
  const lr = await fetch('/api/spec', { headers: { 'Authorization': 'Bearer ' + token } });
  const ld = await lr.json();
  const list = (ld.data && ld.data.list) ? ld.data.list : [];
  const has = list.some(s => s.name === 'GPU-标准');
  if (!has) {
    const cr = await fetch('/api/spec', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
      body: JSON.stringify({
        name: 'GPU-标准', cpu: '4', memory: '16Gi', gpu: '1',
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
")
if [[ "${GPU_SEED_RESULT:-}" == 'seeded' ]]; then
  log "  ✎ GPU-标准 was missing — re-seeded via API"
  sleep 1
  pc_goto "$BASE_URL/specs" >/dev/null 2>&1
  sleep 1
elif [[ "${GPU_SEED_RESULT:-}" != 'exists' ]]; then
  log "  ⚠ GPU-标准 seed check returned: ${GPU_SEED_RESULT:-empty}"
fi

assert_text "TC-2a: 页面标题为规格管理" "规格管理"
assert_text "TC-2b: 包含 CPU-小 规格" "CPU-小"
assert_text "TC-2c: 包含 CPU-大 规格" "CPU-大"
assert_text "TC-2d: 包含 GPU-标准 规格" "GPU-标准"
assert_text "TC-2e: 包含编辑操作" "编辑"

# TC-2f: 创建新规格
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

# TC-2g: 修改规格 CPU
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
