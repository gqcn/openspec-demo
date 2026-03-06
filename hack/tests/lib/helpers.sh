#!/usr/bin/env bash
# =============================================================================
# helpers.sh  —  Low-level helpers: logging, assertions, playwright wrappers
# =============================================================================

# ── Logging ──────────────────────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
pass() { ((PASS++));  log "✓ PASS [$1]"; }
fail() { ((FAIL++));  ERRORS+=("$1: $2"); log "✗ FAIL [$1] — $2"; }

# ── macOS-compatible timeout wrapper ─────────────────────────────────────────
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

# ── Playwright CLI wrappers ──────────────────────────────────────────────────

# Extract the result value from playwright-cli output.
get_result() {
  awk '/^### Result$/{getline; print; exit}' | tr -d '"\r'
}

# Run playwright-cli run-code with configurable timeout (default 15s)
pc_code() {
  local timeout="${2:-$TIMEOUT_MEDIUM}"
  run_timeout "$timeout" playwright-cli run-code "$1" 2>/dev/null
}

# Extract current URL
current_url() {
  run_timeout "$TIMEOUT_SHORT" playwright-cli eval "window.location.href" 2>/dev/null | get_result
}

# Navigate to URL
pc_goto() {
  run_timeout "$TIMEOUT_MEDIUM" playwright-cli goto "$1" >/dev/null 2>&1
}

# ── Assertions ───────────────────────────────────────────────────────────────

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

# Assert page text contains a fragment
assert_text() {
  local tc="$1" text="$2"
  local js_text
  js_text=$(printf '%s' "$text" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read(), ensure_ascii=True))")
  local found
  found=$(pc_code "async page => {
    try {
      const body = await page.evaluate(() => document.body.innerText);
      return body.includes(${js_text}) ? 'true' : 'false';
    } catch(e) { return 'error:' + e.message; }
  }" | get_result)
  if [[ "$found" == "true" ]]; then
    pass "$tc"
  else
    fail "$tc" "expected text '${text}' not found on page"
  fi
}

# Wait for text to appear on page (polling, configurable timeout)
wait_for_text() {
  local text="$1" secs="${2:-30}"
  local js_text
  js_text=$(printf '%s' "$text" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read(), ensure_ascii=True))")
  for _ in $(seq 1 "$secs"); do
    local found
    found=$(run_timeout "$TIMEOUT_SHORT" playwright-cli run-code "async page => {
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

# Check if page body contains text (returns 'true'/'false', no pass/fail)
page_contains() {
  local text="$1"
  local js_text
  js_text=$(printf '%s' "$text" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read(), ensure_ascii=True))")
  run_timeout "$TIMEOUT_SHORT" playwright-cli run-code "async page => {
    const body = await page.evaluate(() => document.body.innerText);
    return body.includes(${js_text}) ? 'true' : 'false';
  }" 2>/dev/null | get_result
}

# ── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
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
}
