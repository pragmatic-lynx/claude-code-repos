#!/bin/bash
set -e

# Formatting script for CCR project

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
action() { echo -e "${BLUE}[FORMAT]${NC} $1"; }

# Check if shfmt is installed
if ! command -v shfmt &> /dev/null; then
    info "shfmt is not installed. Install with:"
    echo "  # Go install:"
    echo "  go install mvdan.cc/sh/v3/cmd/shfmt@latest"
    echo "  # Or download binary from https://github.com/mvdan/sh/releases"
    echo ""
    echo "For now, running basic formatting checks only..."
    USE_SHFMT=false
else
    USE_SHFMT=true
fi

# Format shell scripts
info "Formatting shell scripts..."

shell_scripts=$(find . -name "*.sh" -not -path "./.*" -not -path "./test/*" | sort)

for script in $shell_scripts; do
    action "Processing $script"
    
    if [ "$USE_SHFMT" = true ]; then
        # Use shfmt for proper formatting
        shfmt -i 4 -bn -ci -sr -w "$script"
    else
        # Basic cleanup: remove trailing whitespace
        sed -i 's/[[:space:]]*$//' "$script"
    fi
done

# Format scripts in src/ directory  
if [ -d "src" ]; then
    info "Processing scripts in src/ directory..."
    src_scripts=$(find src -type f -executable -not -name "*.md" | sort)
    for script in $src_scripts; do
        if file "$script" | grep -q "shell script\|bash\|sh"; then
            action "Processing $script"
            
            if [ "$USE_SHFMT" = true ]; then
                shfmt -i 4 -bn -ci -sr -w "$script"
            else
                sed -i 's/[[:space:]]*$//' "$script"
            fi
        fi
    done
fi

info "✅ Formatting complete!"

if [ "$USE_SHFMT" = false ]; then
    echo ""
    info "For better formatting, install shfmt:"
    echo "  go install mvdan.cc/sh/v3/cmd/shfmt@latest"
fi