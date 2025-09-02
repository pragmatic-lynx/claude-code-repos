#!/bin/bash
set -e

# Linting script for CCR project

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if shellcheck is installed
if ! command -v shellcheck &> /dev/null; then
    error "shellcheck is not installed. Install with:"
    echo "  # Ubuntu/Debian:"
    echo "  sudo apt-get install shellcheck"
    echo "  # macOS:"
    echo "  brew install shellcheck"
    echo "  # Fedora/RHEL:"
    echo "  sudo dnf install ShellCheck"
    exit 1
fi

info "Running ShellCheck on all shell scripts..."

# Find all shell scripts
shell_scripts=$(find . -name "*.sh" -not -path "./.*" -not -path "./test/*" | sort)
errors=0

for script in $shell_scripts; do
    info "Checking $script"
    if ! shellcheck "$script"; then
        error "ShellCheck failed for $script"
        ((errors++))
    fi
done

# Check scripts in src/ directory
if [ -d "src" ]; then
    info "Checking scripts in src/ directory..."
    src_scripts=$(find src -type f -executable -not -name "*.md" | sort)
    for script in $src_scripts; do
        if file "$script" | grep -q "shell script\|bash\|sh"; then
            info "Checking $script"
            if ! shellcheck "$script"; then
                error "ShellCheck failed for $script"
                ((errors++))
            fi
        fi
    done
fi

# Summary
if [ $errors -eq 0 ]; then
    info "✅ All shell scripts passed linting!"
    exit 0
else
    error "❌ $errors script(s) failed linting"
    exit 1
fi