#!/usr/bin/env bash
# =============================================================================
# config.sh  —  Shared configuration for E2E tests
# =============================================================================

# ── URLs ─────────────────────────────────────────────────────────────────────
export BASE_URL="${E2E_BASE_URL:-http://localhost:3002}"

# ── Credentials ──────────────────────────────────────────────────────────────
export ADMIN_USER="${E2E_ADMIN_USER:-admin}"
export ADMIN_PASS="${E2E_ADMIN_PASS:-Admin@123456}"
export TEST_USER="${E2E_TEST_USER:-testuser01}"
export TEST_USER_PASS="${E2E_TEST_USER_PASS:-Test@123456}"

# ── Timeouts (seconds) ──────────────────────────────────────────────────────
export TIMEOUT_SHORT="${E2E_TIMEOUT_SHORT:-10}"
export TIMEOUT_MEDIUM="${E2E_TIMEOUT_MEDIUM:-15}"
export TIMEOUT_LONG="${E2E_TIMEOUT_LONG:-25}"
export TIMEOUT_POD="${E2E_TIMEOUT_POD:-120}"

# ── Kubernetes ───────────────────────────────────────────────────────────────
export K8S_NAMESPACE="${E2E_K8S_NAMESPACE:-jupyter}"

# ── Counters ─────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
ERRORS=()
