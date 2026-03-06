#!/usr/bin/env bash
# TC-9  多用户 /share 共享目录访问测试 (Multi-user /share Access)
log ""
log "=== TC-9: 多用户 /share 共享目录访问测试 ==="

SHARE_FILE_ADMIN="admin_share_test_$(date +%s).txt"
SHARE_FILE_USER="${TEST_USER}_share_test_$(date +%s).txt"

# ── Step 0: Clean up TC-8's instance and create fresh admin instance ──
log "  TC-9 setup: 清理旧实例，重新创建 admin 开发机（base-notebook 镜像）..."
do_cleanup_notebooks

# Create admin instance with first image (base-notebook)
do_create_notebook 0

# ── Step 1: Wait for admin's pod ──
log "  TC-9 setup: 等待 admin 开发机 Pod 就绪..."
ADMIN_POD_READY=false
if wait_pod_ready "jupyterlab-admin" "$TIMEOUT_POD"; then
  ADMIN_POD_READY=true
else
  fail "TC-9a: admin 在 /share 创建共享文件" "admin Pod 未就绪，跳过 TC-9"
  fail "TC-9b: testuser01 Pod 可见 /share 共享文件" "跳过"
  fail "TC-9c: testuser01 可在 /share 写入文件" "跳过"
  fail "TC-9d: /share 包含两个用户的文件" "跳过"
fi

if [[ "$ADMIN_POD_READY" == "true" ]]; then
  # ── Step 2: Admin creates a test file in /share ──
  log "  TC-9a: admin 在 /share 创建共享文件..."
  ADMIN_WRITE=$(kubectl -n "$K8S_NAMESPACE" exec jupyterlab-admin -- /bin/bash -c "echo 'hello from admin' > /share/${SHARE_FILE_ADMIN} && cat /share/${SHARE_FILE_ADMIN}" 2>&1)
  if [[ "$ADMIN_WRITE" == *"hello from admin"* ]]; then
    pass "TC-9a: admin 在 /share 创建共享文件成功"
  else
    fail "TC-9a: admin 在 /share 创建共享文件" "写入或读取失败: $ADMIN_WRITE"
  fi

  # ── Step 3: Stop admin's notebook ──
  log "  TC-9 setup: 停止 admin 开发机..."
  do_stop_notebook
  wait_notebook_stopped
  do_delete_notebook_record

  # ── Step 4: Re-enable testuser01 (was disabled in TC-3e) ──
  log "  TC-9 setup: 重新启用 ${TEST_USER}..."
  ENABLE_RESULT=$(do_enable_user "$TEST_USER")
  log "  ${TEST_USER} 启用结果: ${ENABLE_RESULT:-empty}"

  # ── Step 5: Switch to testuser01 ──
  do_logout "$ADMIN_USER"
  do_login "$TEST_USER" "$TEST_USER_PASS"

  # ── Step 6: Create notebook for testuser01 ──
  log "  TC-9 setup: 为 ${TEST_USER} 创建开发机..."
  pc_goto "$BASE_URL/notebooks" >/dev/null 2>&1
  sleep 1
  # Clean up any existing
  if has_stopped_notebook; then
    do_delete_notebook_record
  fi
  do_create_notebook 0

  # ── Step 7: Wait for testuser01's pod ──
  log "  TC-9 setup: 等待 ${TEST_USER} Pod 就绪..."
  TESTUSER_POD_READY=false
  if wait_pod_ready "jupyterlab-${TEST_USER}" "$TIMEOUT_POD"; then
    TESTUSER_POD_READY=true
  fi

  if [[ "$TESTUSER_POD_READY" == "false" ]]; then
    fail "TC-9b: ${TEST_USER} Pod 可见 /share 共享文件" "${TEST_USER} Pod 未就绪"
    fail "TC-9c: ${TEST_USER} 可在 /share 写入文件" "跳过"
    fail "TC-9d: /share 包含两个用户的文件" "跳过"
  else
    # ── Step 8: Verify /share from testuser01's pod ──
    log "  TC-9b: 从 ${TEST_USER} Pod 验证 /share 共享文件..."
    USER_READ=$(kubectl -n "$K8S_NAMESPACE" exec "jupyterlab-${TEST_USER}" -- /bin/bash -c "cat /share/${SHARE_FILE_ADMIN}" 2>&1)
    if [[ "$USER_READ" == *"hello from admin"* ]]; then
      pass "TC-9b: ${TEST_USER} Pod 可见 admin 在 /share 创建的共享文件"
    else
      fail "TC-9b: ${TEST_USER} Pod 可见 /share 共享文件" "读取失败: $USER_READ"
    fi

    # ── Step 9: testuser01 writes to /share ──
    log "  TC-9c: ${TEST_USER} 在 /share 写入文件..."
    USER_WRITE=$(kubectl -n "$K8S_NAMESPACE" exec "jupyterlab-${TEST_USER}" -- /bin/bash -c "echo 'hello from ${TEST_USER}' > /share/${SHARE_FILE_USER} && cat /share/${SHARE_FILE_USER}" 2>&1)
    if [[ "$USER_WRITE" == *"hello from ${TEST_USER}"* ]]; then
      pass "TC-9c: ${TEST_USER} 可在 /share 写入文件"
    else
      fail "TC-9c: ${TEST_USER} 可在 /share 写入文件" "写入或读取失败: $USER_WRITE"
    fi

    # ── Step 10: Verify both files ──
    log "  TC-9d: 验证 /share 包含两个用户的文件..."
    BOTH_FILES=$(kubectl -n "$K8S_NAMESPACE" exec "jupyterlab-${TEST_USER}" -- /bin/bash -c "ls /share/${SHARE_FILE_ADMIN} /share/${SHARE_FILE_USER} 2>&1 && echo 'BOTH_EXIST'" 2>&1)
    if [[ "$BOTH_FILES" == *"BOTH_EXIST"* ]]; then
      pass "TC-9d: /share 目录同时包含 admin 和 ${TEST_USER} 的共享文件"
    else
      fail "TC-9d: /share 包含两个用户的文件" "文件检查失败: $BOTH_FILES"
    fi

    # Cleanup test files
    kubectl -n "$K8S_NAMESPACE" exec "jupyterlab-${TEST_USER}" -- /bin/bash -c "rm -f /share/${SHARE_FILE_ADMIN} /share/${SHARE_FILE_USER}" 2>/dev/null || true
  fi

  # ── Cleanup: stop testuser01's notebook, re-login admin ──
  log "  TC-9 cleanup: 停止 ${TEST_USER} 开发机..."
  do_stop_notebook
  sleep 3

  do_logout "$TEST_USER"
  do_login "$ADMIN_USER" "$ADMIN_PASS"
fi
