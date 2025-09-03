#!/bin/bash

# Cleanup script to remove duplicate CCR entries from shell config

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[CLEANUP]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Detect shell config file
shell_config=""
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
        echo "Unknown shell: $SHELL"
        exit 1
        ;;
esac

if [[ ! -f "$shell_config" ]]; then
    info "Shell config file $shell_config doesn't exist"
    exit 0
fi

log "Cleaning up duplicate CCR entries in $shell_config"

# Create backup
backup_file="${shell_config}.backup-$(date +%Y%m%d-%H%M%S)"
cp "$shell_config" "$backup_file"
info "Created backup: $backup_file"

# Count existing CCR entries
ccr_lines=$(grep -c "ccr activate" "$shell_config" 2>/dev/null || echo "0")
info "Found $ccr_lines CCR activation lines"

if [[ "$ccr_lines" -eq 0 ]]; then
    info "No CCR entries found, nothing to clean"
    exit 0
fi

# Remove CCR-related lines
log "Removing duplicate CCR entries..."

# Create temp file with cleaned content
temp_file="${shell_config}.tmp"
grep -v "ccr activate\|# CCR.*integration\|mise activate" "$shell_config" | \
    # Remove empty lines that might be left behind
    awk '/^$/ {if (empty) next; empty=1; next} {empty=0} 1' > "$temp_file"

# Replace original file
mv "$temp_file" "$shell_config"

info "Cleaned up shell config"
log "You can now run ./install.sh to add clean CCR integration"
log "If something goes wrong, restore from backup: cp $backup_file $shell_config"