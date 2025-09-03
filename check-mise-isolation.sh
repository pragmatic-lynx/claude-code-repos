#!/bin/bash

# Script to verify CCR installation doesn't affect mise settings

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[CHECK]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

log "Checking mise isolation after CCR installation..."

# Check if mise is installed
if ! command -v mise >/dev/null 2>&1; then
    info "mise not installed - CCR installation is completely independent ✅"
    exit 0
fi

info "mise is installed, checking for interference..."

# Check global mise settings
log "Checking global mise settings..."
if mise settings 2>/dev/null | grep -q "aqua.registry_url"; then
    error "Found aqua.registry_url in global mise settings!"
    error "This could interfere with other mise projects"
    info "To fix: mise settings unset -g aqua.registry_url"
    exit 1
else
    info "No aqua registry URL in global settings ✅"
fi

# Check for CCR in mise tools
log "Checking if CCR is registered as mise tool..."
if mise list 2>/dev/null | grep -q "ccr"; then
    warn "CCR is registered in mise tools list"
    info "This is unexpected with the new installation method"
    info "To remove: mise uninstall ccr"
else
    info "CCR not registered in mise ✅"
fi

# Check local .mise.toml files
log "Checking for local mise configurations..."
if [[ -f ".mise.toml" ]] && grep -q "ccr\|aqua.*yourai" ".mise.toml" 2>/dev/null; then
    warn "Found CCR references in local .mise.toml"
    info "This might be leftover from old installation method"
else
    info "No local mise configuration conflicts ✅"
fi

# Verify CCR works independently
log "Verifying CCR works independently..."
if command -v ccr >/dev/null 2>&1; then
    ccr_path=$(which ccr)
    if [[ "$ccr_path" == *".local/bin/ccr"* ]]; then
        info "CCR installed independently at $ccr_path ✅"
    else
        warn "CCR found at unexpected location: $ccr_path"
        info "Expected: ~/.local/bin/ccr"
    fi
    
    # Test CCR version
    if ccr version >/dev/null 2>&1; then
        info "CCR functioning correctly ✅"
    else
        error "CCR not functioning properly"
        exit 1
    fi
else
    error "CCR not found in PATH"
    exit 1
fi

log "✅ All checks passed! CCR installation is properly isolated from mise"
info "Your existing mise projects should not be affected"