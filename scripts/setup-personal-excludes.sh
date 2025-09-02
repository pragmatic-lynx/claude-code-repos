#!/bin/bash
set -e

# Setup Personal Git Excludes for CCR Development
# This script helps configure personal file exclusions

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[EXCLUDE]${NC} $1"; }
action() { echo -e "${BLUE}[ACTION]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

info "Setting up personal Git excludes for CCR development"
echo

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    warn "Not in a Git repository. Please run this from the CCR project root."
    exit 1
fi

# Get the exclude file path
EXCLUDE_FILE=".git/info/exclude"

info "Personal exclude file: $EXCLUDE_FILE"

# Add AI/documentation preferences
action "Adding AI and documentation file excludes..."
cat >> "$EXCLUDE_FILE" << 'EOF'

# Personal CCR Development Excludes
# Added by setup-personal-excludes.sh

# AI and prompt files
CLAUDE.md
CONTEXT.md
PROMPT.md
*prompt*

# Personal documentation preferences
CONTRIBUTING.md
CHANGELOG.md
MISE-SETUP.md

# Development environment
.stfolder/
.shellcheckrc
.dev/

# Personal build artifacts
build-dev-package.sh
demo-*.sh

EOF

info "✅ Personal excludes configured!"
echo

info "The following files will now be ignored locally:"
echo "  • AI context and prompt files (CLAUDE.md, PROMPT.md, etc.)"
echo "  • Personal development configs (.dev/, .shellcheckrc)"
echo "  • Sync folder markers (.stfolder/)"
echo "  • Personal build scripts"
echo

info "To see what's excluded: cat .git/info/exclude"
info "To temporarily track a file: git add -f <filename>"

warn "Note: These excludes only affect your local repository."
warn "Other contributors won't see these exclusions."