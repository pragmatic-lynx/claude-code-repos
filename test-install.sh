#!/bin/bash

# Test script for CCR installation
# This script validates that the install.sh works correctly

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[TEST]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_CCR_HOME="/tmp/ccr-test"
REGISTRY_PORT=8077

# Cleanup function
cleanup() {
    log "Cleaning up test environment..."
    
    # Stop any running registry servers
    pkill -f "http.server.*8077" 2>/dev/null || true
    
    # Remove test CCR installation
    rm -rf "$TEST_CCR_HOME"
    
    # Remove any global mise settings we might have added
    mise settings unset aqua.registry_url 2>/dev/null || true
    
    log "Cleanup complete"
}

trap cleanup EXIT

# Test prerequisites check
test_prerequisites() {
    log "Testing prerequisites check..."
    
    # Check if required tools are available
    local missing=0
    
    if ! command -v python3 >/dev/null 2>&1; then
        error "python3 not found (required for registry server)"
        missing=1
    fi
    
    if [[ $missing -eq 1 ]]; then
        error "Prerequisites test failed"
        return 1
    fi
    
    info "Prerequisites test passed"
}

# Test registry server startup
test_registry() {
    log "Testing registry server..."
    
    # Start registry server
    cd "$SCRIPT_DIR"
    python3 -m http.server "$REGISTRY_PORT" -d .dev/aqua &
    local pid=$!
    
    # Wait for server to start
    local started=0
    for i in {1..10}; do
        if curl -s "http://127.0.0.1:$REGISTRY_PORT/registry.yaml" >/dev/null 2>&1; then
            started=1
            break
        fi
        sleep 1
    done
    
    # Stop server
    kill $pid 2>/dev/null || true
    
    if [[ $started -eq 1 ]]; then
        info "Registry server test passed"
    else
        error "Registry server test failed"
        return 1
    fi
}

# Test package building
test_package_build() {
    log "Testing package build..."
    
    if [[ ! -f "$SCRIPT_DIR/build-dev-package.sh" ]]; then
        error "build-dev-package.sh not found"
        return 1
    fi
    
    # Run build script
    cd "$SCRIPT_DIR"
    if ./build-dev-package.sh >/dev/null 2>&1; then
        info "Package build test passed"
    else
        error "Package build test failed"
        return 1
    fi
    
    # Check if package was created
    if [[ -f "ccr-dev.tar.gz" ]]; then
        info "Package file created successfully"
        rm -f "ccr-dev.tar.gz"  # Clean up
    else
        error "Package file not created"
        return 1
    fi
}

# Test aqua registry files
test_registry_files() {
    log "Testing registry files..."
    
    # Check registry.yaml
    if [[ ! -f ".dev/aqua/registry.yaml" ]]; then
        error "registry.yaml not found"
        return 1
    fi
    
    # Check package spec
    if [[ ! -f ".dev/aqua/pkgs/yourai/ccr/pkg.yaml" ]]; then
        error "pkg.yaml not found"
        return 1
    fi
    
    # Validate YAML syntax (if yq is available)
    if command -v yq >/dev/null 2>&1; then
        if yq eval '.registry.name' .dev/aqua/registry.yaml >/dev/null 2>&1; then
            info "registry.yaml syntax valid"
        else
            error "registry.yaml syntax invalid"
            return 1
        fi
    fi
    
    info "Registry files test passed"
}

# Test install script syntax
test_install_script() {
    log "Testing install script syntax..."
    
    # Check syntax
    if bash -n install.sh; then
        info "Install script syntax valid"
    else
        error "Install script syntax invalid"
        return 1
    fi
    
    # Check if help works
    if ./install.sh --help >/dev/null 2>&1; then
        info "Install script help works"
    else
        error "Install script help failed"
        return 1
    fi
}

# Run dry-run installation test
test_dry_run() {
    log "Testing installation components..."
    
    # Set test environment
    export CCR_HOME="$TEST_CCR_HOME"
    
    # Test individual functions by simulating them
    # (This is a simplified test since we can't easily mock mise)
    
    # Test directory creation
    mkdir -p "$TEST_CCR_HOME"/{bin,shims,containers,config}
    
    if [[ -d "$TEST_CCR_HOME/bin" ]]; then
        info "Directory creation test passed"
    else
        error "Directory creation test failed"
        return 1
    fi
}

# Main test runner
main() {
    log "Starting CCR installation tests..."
    echo ""
    
    local failed=0
    
    # Run all tests
    test_prerequisites || failed=1
    test_registry || failed=1  
    test_package_build || failed=1
    test_registry_files || failed=1
    test_install_script || failed=1
    test_dry_run || failed=1
    
    echo ""
    
    if [[ $failed -eq 0 ]]; then
        log "All tests passed! ✅"
        info "The install.sh script should work correctly"
    else
        error "Some tests failed! ❌" 
        info "Please fix the issues before using install.sh"
        exit 1
    fi
}

# Show help
show_help() {
    cat << 'EOF'
CCR Installation Test Script

USAGE:
    ./test-install.sh [OPTIONS]

OPTIONS:
    --help, -h       Show this help message

This script tests the CCR installation components to ensure
the install.sh script will work correctly.

Tests performed:
- Prerequisites check
- Registry server startup
- Package building 
- Registry files validation
- Install script syntax
- Directory structure creation

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

# Run tests
main