#!/usr/bin/env bash
# =============================================================================
# run-e2e.sh  —  E2E Test Runner
#
# Runs all test cases (or specific ones) with proper setup/teardown.
#
# Usage:
#   bash hack/tests/run-e2e.sh               # Run all tests
#   bash hack/tests/run-e2e.sh tc01 tc03      # Run only TC-1 and TC-3
#   bash hack/tests/run-e2e.sh --list         # List available test cases
#
# Environment variables (all optional):
#   E2E_BASE_URL        Frontend URL        (default: http://localhost:3002)
#   E2E_ADMIN_USER      Admin username      (default: admin)
#   E2E_ADMIN_PASS      Admin password      (default: Admin@123456)
#   E2E_TIMEOUT_POD     Pod wait timeout    (default: 120)
#   E2E_K8S_NAMESPACE   Kubernetes namespace(default: jupyter)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load shared libraries ────────────────────────────────────────────────────
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/helpers.sh"
source "$SCRIPT_DIR/lib/actions.sh"

# ── Discover test cases ──────────────────────────────────────────────────────
TC_DIR="$SCRIPT_DIR/cases"
declare -a ALL_CASES=()
for f in "$TC_DIR"/tc*.sh; do
  [[ -f "$f" ]] && ALL_CASES+=("$(basename "$f" .sh)")
done

# ── Parse arguments ──────────────────────────────────────────────────────────
if [[ "${1:-}" == "--list" ]]; then
  echo "Available test cases:"
  for tc in "${ALL_CASES[@]}"; do
    desc=$(head -5 "$TC_DIR/${tc}.sh" | grep '^# *TC-' | head -1 || echo "$tc")
    echo "  $tc  —  $desc"
  done
  exit 0
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  head -16 "$0" | tail -12
  exit 0
fi

# Determine which cases to run
declare -a RUN_CASES=()
if [[ $# -gt 0 ]]; then
  for arg in "$@"; do
    if [[ -f "$TC_DIR/${arg}.sh" ]]; then
      RUN_CASES+=("$arg")
    else
      log "WARNING: Unknown test case '$arg', skipping."
    fi
  done
else
  RUN_CASES=("${ALL_CASES[@]}")
fi

if [[ ${#RUN_CASES[@]} -eq 0 ]]; then
  log "No test cases to run."
  exit 1
fi

# ── Trap: cleanup on exit ────────────────────────────────────────────────────
cleanup() {
  log ""
  log "Cleaning up browser sessions..."
  playwright-cli kill-all 2>/dev/null || true
}
trap cleanup EXIT

# ── Setup: open browser ──────────────────────────────────────────────────────
log "=== AI Training Platform E2E Test Suite ==="
log "Running ${#RUN_CASES[@]} test case(s): ${RUN_CASES[*]}"
log ""

playwright-cli kill-all 2>/dev/null || true
sleep 1
run_timeout "$TIMEOUT_SHORT" playwright-cli open --headed "$BASE_URL" >/dev/null 2>&1
sleep 3

# ── Run selected test cases ──────────────────────────────────────────────────
for tc in "${RUN_CASES[@]}"; do
  log ""
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "  Running: $tc"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  source "$TC_DIR/${tc}.sh"
done

# ── Summary ──────────────────────────────────────────────────────────────────
print_summary

if [[ "$FAIL" -eq 0 ]]; then
  log "All tests passed!"
  exit 0
else
  log "Some tests failed."
  exit 1
fi
