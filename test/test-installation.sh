#!/bin/bash
set -e

# Test script for CCR installation

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[TEST]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

test_count=0
pass_count=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((test_count++))
    info "Running: $test_name"
    
    if eval "$test_command"; then
        info "✅ PASS: $test_name"
        ((pass_count++))
    else
        error "❌ FAIL: $test_name"
    fi
    echo
}

info "Testing CCR Installation..."
echo

# Test 1: Check ccr binary exists
run_test "CCR binary exists" "[ -f '$HOME/.local/bin/ccr' ]"

# Test 2: Check ccr is executable
run_test "CCR binary is executable" "[ -x '$HOME/.local/bin/ccr' ]"

# Test 3: Check ccr version command
run_test "CCR version command works" "ccr version >/dev/null 2>&1"

# Test 4: Check ccr help command
run_test "CCR help command works" "ccr help >/dev/null 2>&1"

# Test 5: Check shim directory exists
run_test "Shim directory exists" "[ -d '$HOME/.ccr/shims' ]"

# Test 6: Check claude shim exists
run_test "Claude shim exists" "[ -f '$HOME/.ccr/shims/claude' ]"

# Test 7: Check state management script exists
run_test "State management script exists" "[ -f '$HOME/.ccr/bin/ccr-state' ]"

# Test 8: Check repo manager script exists
run_test "Repo manager script exists" "[ -f '$HOME/repos/ccdocker/src/repo-manager.sh' ]"

# Test 9: Check docker-compose directory exists
run_test "Docker compose directory exists" "[ -d '$HOME/docker-compose' ]"

# Test 10: Check activation works
export PATH="$HOME/.local/bin:$PATH"
run_test "CCR activation works" "eval \"\$(ccr activate zsh)\" && which claude >/dev/null 2>&1"

# Summary
echo "================================="
info "Test Results: $pass_count/$test_count passed"

if [ "$pass_count" -eq "$test_count" ]; then
    info "🎉 All installation tests passed!"
    exit 0
else
    error "❌ $((test_count - pass_count)) test(s) failed"
    exit 1
fi