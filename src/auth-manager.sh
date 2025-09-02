#!/bin/bash

# Claude Code Authentication Manager
# Manages persistent authentication across container recreations

CLAUDE_DIR="/home/claude/.claude"
AUTH_FILE="$CLAUDE_DIR/.credentials.json" 
CONFIG_FILE="$CLAUDE_DIR/config.json"
BACKUP_DIR="/workspace/.claude-auth-backup"
HOST_AUTH_API="http://homelab:8004/api/claude/auth"  # ACI backend API endpoint

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[AUTH-MANAGER]${NC} $1"
}

error() {
    echo -e "${RED}[AUTH-ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[AUTH-SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[AUTH-WARNING]${NC} $1"
}

# Check if authentication is valid
check_auth() {
    log "Checking Claude Code authentication..."
    
    if [ ! -f "$AUTH_FILE" ]; then
        error "No authentication file found at $AUTH_FILE"
        return 1
    fi
    
    # Check if access token exists and is not expired
    local expires_at=$(jq -r '.claudeAiOauth.expiresAt' "$AUTH_FILE" 2>/dev/null)
    local current_time=$(date +%s)000  # Convert to milliseconds
    
    if [ "$expires_at" = "null" ] || [ -z "$expires_at" ]; then
        error "Invalid authentication file - missing expiration"
        return 1
    fi
    
    if [ "$current_time" -gt "$expires_at" ]; then
        error "Authentication token expired"
        return 1
    fi
    
    success "Authentication valid (expires: $(date -d @$((expires_at/1000))))"
    return 0
}

# Test authentication by running claude command
test_claude_auth() {
    log "Testing Claude Code CLI authentication..."
    
    # Test with a simple command
    local test_output
    test_output=$(timeout 10 /home/claude/.npm-global/bin/claude --version 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && [[ "$test_output" == *"Claude Code"* ]]; then
        success "Claude Code CLI authentication working"
        return 0
    else
        error "Claude Code CLI authentication failed: $test_output"
        return 1
    fi
}

# Backup current authentication
backup_auth() {
    log "Backing up authentication files..."
    
    mkdir -p "$BACKUP_DIR"
    
    if [ -f "$AUTH_FILE" ]; then
        cp "$AUTH_FILE" "$BACKUP_DIR/.credentials.json.$(date +%s)"
        log "Backed up credentials file"
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$BACKUP_DIR/config.json.$(date +%s)"
        log "Backed up config file"
    fi
    
    # Keep only last 5 backups
    find "$BACKUP_DIR" -name "*.credentials.json.*" -type f | sort | head -n -5 | xargs rm -f
    find "$BACKUP_DIR" -name "config.json.*" -type f | sort | head -n -5 | xargs rm -f
}

# Restore authentication from backup or ACI backend
restore_auth() {
    log "Attempting to restore authentication..."
    
    # Try to get auth from ACI backend first
    if command -v curl >/dev/null 2>&1; then
        log "Checking ACI backend for authentication..."
        
        local auth_response
        auth_response=$(curl -s -f "$HOST_AUTH_API" 2>/dev/null || echo "")
        
        if [ -n "$auth_response" ] && echo "$auth_response" | jq -e '.claudeAiOauth' >/dev/null 2>&1; then
            log "Found authentication on ACI backend"
            echo "$auth_response" > "$AUTH_FILE"
            success "Restored authentication from ACI backend"
            return 0
        else
            warn "No valid authentication found on ACI backend"
        fi
    fi
    
    # Try to restore from local backup
    local latest_backup=$(find "$BACKUP_DIR" -name ".credentials.json.*" -type f 2>/dev/null | sort | tail -1)
    
    if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
        log "Restoring from backup: $latest_backup"
        cp "$latest_backup" "$AUTH_FILE"
        success "Restored authentication from backup"
        return 0
    fi
    
    error "No authentication backup found"
    return 1
}

# Upload current authentication to ACI backend
upload_auth() {
    log "Uploading authentication to ACI backend..."
    
    if [ ! -f "$AUTH_FILE" ]; then
        error "No authentication file to upload"
        return 1
    fi
    
    if command -v curl >/dev/null 2>&1; then
        local response
        response=$(curl -s -X POST -H "Content-Type: application/json" \
                       --data @"$AUTH_FILE" \
                       "$HOST_AUTH_API" 2>/dev/null || echo "failed")
        
        if [ "$response" = "failed" ] || [ -z "$response" ]; then
            warn "Failed to upload authentication to ACI backend"
            return 1
        else
            success "Authentication uploaded to ACI backend"
            return 0
        fi
    else
        warn "curl not available, cannot upload to ACI backend"
        return 1
    fi
}

# Interactive login process
interactive_login() {
    log "Starting interactive Claude Code login..."
    
    # Backup existing auth first
    backup_auth
    
    log "Running claude code login..."
    echo "Please complete the OAuth login process..."
    
    # Run the interactive login
    if /home/claude/.npm-global/bin/claude code login; then
        success "Login completed successfully"
        
        # Verify the authentication was created
        if check_auth; then
            # Upload to ACI backend for persistence
            upload_auth
            return 0
        else
            error "Login completed but authentication file is invalid"
            return 1
        fi
    else
        error "Login failed"
        return 1
    fi
}

# Main authentication setup function
setup_auth() {
    log "Setting up Claude Code authentication..."
    
    # Ensure claude directory exists
    mkdir -p "$CLAUDE_DIR"
    chown -R claude:claude "$CLAUDE_DIR"
    
    # Check if we already have valid auth
    if check_auth && test_claude_auth; then
        success "Authentication already valid"
        # Still backup and upload for safety
        backup_auth
        upload_auth
        return 0
    fi
    
    # Try to restore from backup or ACI backend
    if restore_auth; then
        if check_auth && test_claude_auth; then
            success "Authentication restored successfully"
            return 0
        else
            warn "Restored authentication is invalid"
        fi
    fi
    
    # If all else fails, prompt for interactive login
    warn "No valid authentication found. Interactive login required."
    echo
    echo "To authenticate Claude Code CLI:"
    echo "1. Run: /usr/local/bin/auth-manager.sh login"
    echo "2. Or run: claude code login"
    echo
    return 1
}

# Command line interface
case "${1:-setup}" in
    "check")
        check_auth && test_claude_auth
        ;;
    "backup")
        backup_auth
        ;;
    "restore")
        restore_auth
        ;;
    "upload")
        upload_auth
        ;;
    "login")
        interactive_login
        ;;
    "test")
        test_claude_auth
        ;;
    "setup"|*)
        setup_auth
        ;;
esac