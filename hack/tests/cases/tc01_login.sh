#!/usr/bin/env bash
# TC-1  登录验证 (Login)
log ""
log "=== TC-1: 登录验证 ==="

do_login "$ADMIN_USER" "$ADMIN_PASS"

assert_url "TC-1a: 登录后跳转到 /notebooks" "/notebooks"
assert_text "TC-1b: 侧边栏显示管理员菜单" "规格管理"
assert_text "TC-1c: 顶部显示用户名" "admin"
