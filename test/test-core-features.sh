#!/bin/bash
set -e

# Test script for CCR core functionality

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

# Setup test environment
export PATH="$HOME/.local/bin:$HOME/.ccr/shims:$PATH"
TEST_REPO="ccr-test-$(date +%s)"

cleanup() {
    info "Cleaning up test repo: $TEST_REPO"
    ccr repo stop "$TEST_REPO" 2>/dev/null || true
    rm -rf "$HOME/repos/$TEST_REPO" 2>/dev/null || true
    rm -f "$HOME/docker-compose/docker-compose.$TEST_REPO.yml" 2>/dev/null || true
}

trap cleanup EXIT

info "Testing CCR Core Features..."
echo

# Test 1: Repo initialization
mkdir -p "$HOME/repos/$TEST_REPO"
echo "# Test repo" > "$HOME/repos/$TEST_REPO/README.md"
run_test "Repository initialization" "ccr repo init '$TEST_REPO' >/dev/null 2>&1"

# Test 2: Check compose file created
run_test "Docker compose file created" "[ -f '$HOME/docker-compose/docker-compose.$TEST_REPO.yml' ]"

# Test 3: Repo listing
run_test "Repository appears in list" "ccr repo list | grep -q '$TEST_REPO'"

# Test 4: Container start
if command -v docker >/dev/null 2>&1; then
    run_test "Container starts successfully" "timeout 60 ccr repo start '$TEST_REPO' >/dev/null 2>&1"
    
    # Test 5: Container status check
    run_test "Container shows as running" "ccr repo list | grep '$TEST_REPO' | grep -q 'running'"
    
    # Test 6: Container stop
    run_test "Container stops successfully" "ccr repo stop '$TEST_REPO' >/dev/null 2>&1"
else
    warn "Docker not available - skipping container tests"
    ((test_count+=3))
fi

# Test 7: State management
run_test "State save works" "'$HOME/.ccr/bin/ccr-state' save '$TEST_REPO'"

# Test 8: State retrieval
run_test "State get works" "[ \"\$('$HOME/.ccr/bin/ccr-state' get)\" = '$TEST_REPO' ]"

# Test 9: Continue command
run_test "Continue command works" "ccr continue --help >/dev/null 2>&1 || ccr c --help >/dev/null 2>&1"

# Test 10: Repo detection from directory
cd "$HOME/repos/$TEST_REPO"
run_test "Repo detection works" "ccr detect | grep -q '$TEST_REPO'"
cd - >/dev/null

# Summary
echo "================================="
info "Test Results: $pass_count/$test_count passed"

if [ "$pass_count" -eq "$test_count" ]; then
    info "🎉 All core feature tests passed!"
    exit 0
else
    error "❌ $((test_count - pass_count)) test(s) failed"
    exit 1
fi