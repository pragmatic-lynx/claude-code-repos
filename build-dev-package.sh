#!/bin/bash

# Build development package for CCR mise testing

set -e

BUILD_DIR="/tmp/ccr-build"
PACKAGE_NAME="ccr-dev.tar.gz"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔨 Building CCR development package..."

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create main ccr binary from repo-manager
cat > "$BUILD_DIR/ccr" << 'EOF'
#!/bin/bash

# CCR (Claude Code Repo) - Development Version
# This is a simplified version for local mise testing

CCR_HOME="${CCR_HOME:-$HOME/.ccr}"
REPO_BASE_DIR="${HOME}/repos"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[CCR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Simple repo detection
detect_repo() {
    local current_dir="$PWD"
    
    # Check if we're inside a repos subdirectory
    if [[ "$current_dir" == "$REPO_BASE_DIR"/* ]]; then
        local relative_path="${current_dir#$REPO_BASE_DIR/}"
        local repo_name="${relative_path%%/*}"
        echo "$repo_name"
        return 0
    fi
    
    # Check if current directory is a repo
    if [[ "$(dirname "$current_dir")" == "$REPO_BASE_DIR" ]]; then
        echo "$(basename "$current_dir")"
        return 0
    fi
    
    return 1
}

case "${1:-}" in
    "version"|"--version")
        echo "ccr v1.0.0-dev (installed via mise)"
        ;;
    
    "repo"|"r")
        shift
        if [ -f "$CCR_HOME/bin/ccr-repo-manager" ]; then
            exec "$CCR_HOME/bin/ccr-repo-manager" "$@"
        else
            error "CCR system not fully installed. Run: ccr install"
            exit 1
        fi
        ;;
    
    "activate")
        if [ -f "$CCR_HOME/bin/ccr-activate" ]; then
            exec "$CCR_HOME/bin/ccr-activate" "$@"
        else
            echo 'export PATH="$HOME/.ccr/shims:$PATH"'
        fi
        ;;
    
    "install")
        log "Installing full CCR system..."
        
        # Create directories
        mkdir -p "$CCR_HOME"/{bin,shims,containers,config}
        
        # Copy source files if available (for local development)
        # Try multiple possible source locations (specific paths only)
        source_dir=""
        for possible_dir in \
            "$PWD/src" \
            "$(dirname "$PWD")/src" \
            "/home/dev/repos/ccdocker/src" \
            "/home/dev/repos/claude-code-repos/src" \
            "$HOME/repos/ccdocker/src" \
            "$HOME/repos/claude-code-repos/src"; do
            if [ -d "$possible_dir" ] && [ -f "$possible_dir/repo-manager.sh" ]; then
                source_dir="$possible_dir"
                break
            fi
        done
        
        if [ -n "$source_dir" ] && [ -d "$source_dir" ]; then
            log "Installing from local development source: $source_dir"
            
            # Function to copy and fix line endings
            copy_and_fix_endings() {
                local src="$1"
                local dest="$2"
                if [ -f "$src" ]; then
                    # Copy and fix line endings
                    if command -v dos2unix >/dev/null 2>&1; then
                        cp "$src" "$dest" && dos2unix "$dest" 2>/dev/null
                    else
                        # Fallback: use sed to remove carriage returns
                        sed 's/\r$//' "$src" > "$dest"
                    fi
                    return 0
                else
                    return 1
                fi
            }
            
            # Copy core files with line ending fixes
            copy_and_fix_endings "$source_dir/repo-manager.sh" "$CCR_HOME/bin/ccr-repo-manager" || warn "repo-manager.sh not found"
            copy_and_fix_endings "$source_dir/aliases.sh" "$CCR_HOME/bin/ccr-aliases" || warn "aliases.sh not found"
            
            # Copy container configs (fix line endings for shell scripts)
            for file in "$source_dir"/docker-compose*.yml; do
                if [ -f "$file" ]; then
                    cp "$file" "$CCR_HOME/containers/"
                fi
            done
            
            for file in "$source_dir"/*.sh; do
                if [ -f "$file" ]; then
                    filename=$(basename "$file")
                    copy_and_fix_endings "$file" "$CCR_HOME/containers/$filename"
                fi
            done
            
            if [ -f "$source_dir/Dockerfile.claude" ]; then
                cp "$source_dir/Dockerfile.claude" "$CCR_HOME/containers/"
            fi
            
            chmod +x "$CCR_HOME/bin"/* 2>/dev/null || true
            chmod +x "$CCR_HOME/containers"/*.sh 2>/dev/null || true
            
            info "CCR system installed from local development source"
        else
            # Try to download from GitHub (future)
            warn "Local source not found in common locations."
            warn "Searched: ./src, ../src, ~/repos/{ccdocker,claude-code-repos}/src"
            warn "GitHub download not yet implemented."
            warn "Manual installation required."
        fi
        
        log "CCR installation complete!"
        info "Next steps:"
        info "  1. Add to shell: echo 'eval \"\$(ccr activate zsh)\"' >> ~/.zshrc"
        info "  2. Reload shell: source ~/.zshrc"
        info "  3. Initialize repos: ccr repo init <repo-name>"
        ;;
    
    "detect"|"status")
        if repo_name=$(detect_repo); then
            info "Current repo: $repo_name"
            if [ -f "$CCR_HOME/containers/docker-compose.${repo_name}.yml" ]; then
                info "Container: configured ✓"
            else
                warn "Container: not configured (run: ccr repo init $repo_name)"
            fi
        else
            warn "Not in a repo directory"
            info "Available repos: $(ls "$REPO_BASE_DIR" 2>/dev/null | tr '\n' ' ' || echo 'none')"
        fi
        ;;
    
    "help"|"--help"|"")
        cat << 'HELP'
CCR (Claude Code Repo) - Development Version

USAGE:
    ccr <command> [args]

COMMANDS:
    version              Show version
    install              Install full CCR system
    repo, r              Manage repo containers (after install)
    activate <shell>     Generate shell integration
    detect, status       Show current repo context
    help                 Show this help

EXAMPLES:
    ccr install          # Install full CCR system
    ccr repo init my-app # Initialize repo container
    ccr detect           # Show current repo context

This is the development version installed via mise.
Run 'ccr install' to set up the full CCR system.

HELP
        ;;
    *)
        if repo_name=$(detect_repo); then
            info "Detected repo: $repo_name"
            info "Run 'ccr install' first, then use 'ccr repo' commands"
        else
            error "Unknown command: ${1:-}"
            info "Use 'ccr help' for usage information"
            exit 1
        fi
        ;;
esac
EOF

chmod +x "$BUILD_DIR/ccr"

# Create package
cd "$SRC_DIR"
tar -czf "$PACKAGE_NAME" -C "$BUILD_DIR" ccr

echo "✅ Package created: $PACKAGE_NAME"
echo "📦 Contents:"
tar -tzf "$PACKAGE_NAME"

# Test the binary
echo ""
echo "🧪 Testing binary:"
"$BUILD_DIR/ccr" version

echo ""
echo "🎉 Development package ready for installation!"
echo ""
echo "Usage:"
echo "  1. Run the install script: ./install.sh"
echo "  2. Restart your shell or: source ~/.zshrc"
echo "  3. Initialize repos: ccr repo init <repo-name>"