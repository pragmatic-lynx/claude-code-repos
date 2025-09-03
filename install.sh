#!/bin/bash

set -euo pipefail

# CCR Installation Script
# Simplified installation that handles all dependencies automatically

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[CCR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
CCR_HOME="${CCR_HOME:-$HOME/.ccr}"
REPO_BASE_DIR="${HOME}/repos"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY_PORT=8077

# Cleanup function
cleanup() {
    # Clean up any temporary files if needed
    if [[ -f "$SCRIPT_DIR/ccr-dev.tar.gz" ]]; then
        rm -f "$SCRIPT_DIR/ccr-dev.tar.gz"
    fi
}
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # We only need basic shell tools, which should be available on all systems
    info "All prerequisites satisfied"
}



# Build development package
build_dev_package() {
    log "Building development package..."
    
    if [[ -f "$SCRIPT_DIR/build-dev-package.sh" ]]; then
        cd "$SCRIPT_DIR"
        ./build-dev-package.sh
    else
        error "build-dev-package.sh not found"
        exit 1
    fi
}

# Install CCR directly from local tarball
install_ccr() {
    log "Installing CCR to local bin directory..."
    
    # Create local bin directory
    mkdir -p "$HOME/.local/bin"
    
    # Extract CCR binary from our built package
    cd "$SCRIPT_DIR"
    if [[ -f "ccr-dev.tar.gz" ]]; then
        tar -xzf "ccr-dev.tar.gz" -C "$HOME/.local/bin/"
        chmod +x "$HOME/.local/bin/ccr"
        info "CCR binary extracted to ~/.local/bin/ccr"
    else
        error "ccr-dev.tar.gz not found. Package build may have failed."
        exit 1
    fi
    
    # Add to current PATH for immediate use
    export PATH="$HOME/.local/bin:$PATH"
    
    # Verify installation
    if command -v ccr >/dev/null 2>&1; then
        local version
        version=$(ccr version)
        info "CCR installed: $version"
    else
        error "CCR installation failed - check if ~/.local/bin is in your PATH"
        info "Try: export PATH=\"\$HOME/.local/bin:\$PATH\""
        exit 1
    fi
}

# Install full CCR system
setup_ccr_system() {
    log "Setting up full CCR system..."
    
    # Run the ccr install command to set up the full system
    ccr install
    
    # Create repos directory if it doesn't exist
    mkdir -p "$REPO_BASE_DIR"
    info "Created repos directory: $REPO_BASE_DIR"
}

# Create shell integration script
setup_shell_integration() {
    log "Setting up shell integration..."
    
    local shell_config=""
    case "$SHELL" in
        */zsh)
            shell_config="$HOME/.zshrc"
            ;;
        */bash)
            shell_config="$HOME/.bashrc"
            ;;
        */fish)
            shell_config="$HOME/.config/fish/config.fish"
            ;;
        *)
            warn "Unknown shell: $SHELL"
            info "Add this to your shell config: eval \"\$(ccr activate \$(basename \$SHELL))\""
            return
            ;;
    esac
    
    # Check if already configured - look for our specific comment marker
    if grep -q "# CCR (Claude Code Repo) integration" "$shell_config" 2>/dev/null; then
        info "Shell integration already configured in $shell_config"
        return
    fi
    
    # Also remove any old CCR entries to prevent duplicates
    if grep -q "ccr activate" "$shell_config" 2>/dev/null; then
        warn "Found existing CCR entries, cleaning them up..."
        # Create backup
        cp "$shell_config" "${shell_config}.ccr-backup"
        # Remove old CCR lines
        grep -v "ccr activate" "$shell_config" > "${shell_config}.tmp" && mv "${shell_config}.tmp" "$shell_config"
    fi
    
    # Add ccr activation and PATH to shell config
    echo "" >> "$shell_config"
    echo "# CCR (Claude Code Repo) integration" >> "$shell_config"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_config"
    echo 'eval "$(ccr activate $(basename $SHELL))"' >> "$shell_config"
    
    info "Shell integration added to $shell_config"
    info "Run 'source $shell_config' or restart your shell to activate"
}

# Main installation flow
main() {
    log "Starting CCR installation..."
    
    # Run all installation steps
    check_prerequisites
    build_dev_package
    install_ccr
    setup_ccr_system
    setup_shell_integration
    
    # Success message
    log "Installation complete! ✨"
    echo ""
    info "Next steps:"
    info "  1. Restart your shell or run: source ~/.$(basename "$SHELL")rc"
    info "  2. Initialize a repo: ccr repo init my-project"
    info "  3. Or clone from Git: ccr config wizard (configure Git provider first)"
    echo ""
    info "For help: ccr help"
    info "To check status: ccr detect"
    echo ""
}

# Help function
show_help() {
    cat << 'EOF'
CCR Installation Script

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    --help, -h       Show this help message
    --clean          Clean install (remove existing CCR installation)
    --clean-shell    Clean shell config (remove duplicate CCR entries)

ENVIRONMENT VARIABLES:
    CCR_HOME         CCR installation directory (default: ~/.ccr)

This script will:
1. Build CCR development package
2. Install CCR to ~/.local/bin (independent of mise)
3. Set up full CCR system
4. Configure shell integration

NOTE: This installation is completely independent of mise and will not
affect your existing mise projects or global mise settings.

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --clean)
            warn "Cleaning existing CCR installation..."
            rm -rf "$CCR_HOME"
            rm -f "$HOME/.local/bin/ccr"
            ;;
        --clean-shell)
            log "Cleaning shell configuration..."
            "$SCRIPT_DIR/cleanup-shell.sh"
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

# Run main installation
main