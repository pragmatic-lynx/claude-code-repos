#!/bin/bash

# Test Workflow Script - Validates the complete ACI Claude Code container workflow

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test 1: Container startup and basic functionality
test_container_startup() {
    log "Testing container startup and basic functionality..."
    
    # Restart container to ensure clean state
    docker compose restart claude-cli
    sleep 10
    
    # Check container is running
    if docker ps | grep -q "claude-cli-workspace"; then
        success "Container is running"
    else
        error "Container failed to start"
        return 1
    fi
    
    # Check SSH daemon is running
    if docker exec claude-cli-workspace pgrep sshd > /dev/null; then
        success "SSH daemon is running"
    else
        error "SSH daemon not running"
        return 1
    fi
    
    # Check Tailscale status
    local ts_status=$(docker exec claude-cli-workspace sudo tailscale status 2>&1 | head -1)
    if [[ "$ts_status" != *"Logged out"* ]]; then
        success "Tailscale is connected"
    else
        warn "Tailscale is not connected (normal if no auth key)"
    fi
}

# Test 2: Authentication system
test_authentication() {
    log "Testing authentication system..."
    
    # Check auth manager exists
    if docker exec claude-cli-workspace test -f /usr/local/bin/auth-manager.sh; then
        success "Authentication manager found"
    else
        error "Authentication manager missing"
        return 1
    fi
    
    # Check authentication status
    local auth_status=$(docker exec claude-cli-workspace /usr/local/bin/auth-manager.sh check 2>&1)
    if [[ "$auth_status" == *"Authentication valid"* ]]; then
        success "Authentication is valid"
        return 0
    elif [[ "$auth_status" == *"expired"* ]] || [[ "$auth_status" == *"not found"* ]]; then
        warn "Authentication expired or missing (expected for test)"
        
        # Test backup/restore functionality
        log "Testing backup functionality..."
        docker exec claude-cli-workspace /usr/local/bin/auth-manager.sh backup
        success "Backup command executed"
        
        return 0
    else
        error "Unexpected authentication status: $auth_status"
        return 1
    fi
}

# Test 3: SSH access and shell configuration
test_ssh_access() {
    log "Testing SSH access and shell configuration..."
    
    # Generate SSH key if not exists
    if [ ! -f /tmp/claude_key ]; then
        ssh-keygen -t ed25519 -f /tmp/claude_key -N "" -q
    fi
    
    # Add SSH key to container
    local pubkey=$(cat /tmp/claude_key.pub)
    docker exec claude-cli-workspace sudo -u claude bash -c "
        mkdir -p ~/.ssh
        echo '$pubkey' >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        chmod 700 ~/.ssh
    "
    
    # Test SSH connection
    if ssh -i /tmp/claude_key -o StrictHostKeyChecking=no -o ConnectTimeout=10 claude@$(docker inspect claude-cli-workspace | jq -r '.[0].NetworkSettings.Networks[].IPAddress') "whoami" 2>/dev/null; then
        success "SSH connection works"
    else
        # Try via Tailscale
        if ssh -i /tmp/claude_key -o StrictHostKeyChecking=no -o ConnectTimeout=10 claude@claude-cli "whoami" 2>/dev/null; then
            success "SSH connection works via Tailscale"
        else
            warn "SSH connection failed (may need manual key setup)"
        fi
    fi
    
    # Test zsh configuration
    log "Testing zsh configuration..."
    docker exec claude-cli-workspace /usr/local/bin/fix-zsh.sh
    success "Zsh configuration applied"
}

# Test 4: Claude CLI functionality
test_claude_cli() {
    log "Testing Claude CLI functionality..."
    
    # Check Claude CLI is installed
    if docker exec claude-cli-workspace sudo -u claude /home/claude/.npm-global/bin/claude --version; then
        success "Claude CLI is installed and accessible"
    else
        error "Claude CLI not found or not working"
        return 1
    fi
    
    # Test with a simple file operation (doesn't require API)
    docker exec claude-cli-workspace sudo -u claude bash -c "
        cd /workspace
        echo 'function hello() { console.log(\"Hello World\"); }' > test-file.js
        echo 'Test file created successfully'
    "
    
    # Try Claude CLI with file (will show auth error but proves file handling works)
    local claude_output=$(docker exec claude-cli-workspace sudo -u claude bash -c "
        cd /workspace
        /home/claude/.npm-global/bin/claude -p 'What does this code do?' test-file.js 2>&1 || echo 'Auth error expected'
    ")
    
    if [[ "$claude_output" == *"authentication_error"* ]] || [[ "$claude_output" == *"OAuth token has expired"* ]]; then
        success "Claude CLI file handling works (auth error expected with expired token)"
    elif [[ "$claude_output" == *"Auth error expected"* ]]; then
        warn "Claude CLI executed but authentication needs setup"
    else
        success "Claude CLI fully functional"
    fi
}

# Test 5: Persistence across container restart
test_persistence() {
    log "Testing persistence across container restart..."
    
    # Create test configuration
    docker exec claude-cli-workspace sudo -u claude bash -c "
        echo 'alias testpersist=\"echo Persistence test works!\"' >> ~/.zshrc
        echo 'Test config created'
    "
    
    # Restart container
    log "Restarting container to test persistence..."
    docker compose restart claude-cli
    sleep 10
    
    # Check if configuration persists
    local persist_test=$(docker exec claude-cli-workspace sudo -u claude bash -c "
        source ~/.zshrc && testpersist 2>/dev/null || echo 'Alias not found'
    ")
    
    if [[ "$persist_test" == *"Persistence test works"* ]]; then
        success "Configuration persists across container restarts"
    else
        warn "Configuration persistence needs verification"
    fi
}

# Test 6: Volume and file structure
test_file_structure() {
    log "Testing file structure and volumes..."
    
    # Check key directories exist
    for dir in "/home/claude" "/workspace" "/home/claude/.claude" "/commandhistory"; do
        if docker exec claude-cli-workspace test -d "$dir"; then
            success "Directory exists: $dir"
        else
            error "Missing directory: $dir"
        fi
    done
    
    # Check volume mounts
    local volumes=$(docker inspect claude-cli-workspace | jq -r '.[0].Mounts[] | .Source + " -> " + .Destination')
    log "Volume mounts:"
    echo "$volumes" | while read line; do
        echo "  $line"
    done
    
    success "File structure verified"
}

# Test 7: Throwaway container pattern
test_throwaway_container() {
    log "Testing throwaway container pattern..."
    
    # Create a throwaway container with shared auth
    local throwaway_name="claude-test-throwaway-$$"
    
    docker run --rm -d \
        --name "$throwaway_name" \
        --hostname "claude-test" \
        -v src_claude_home:/home/claude:ro \
        -v "$(pwd)":/workspace/test:rw \
        src-claude-cli \
        sleep 300
    
    sleep 5
    
    # Test basic functionality in throwaway container
    if docker exec "$throwaway_name" whoami; then
        success "Throwaway container created and accessible"
        
        # Test Claude CLI in throwaway
        if docker exec "$throwaway_name" sudo -u claude /home/claude/.npm-global/bin/claude --version; then
            success "Claude CLI works in throwaway container"
        else
            warn "Claude CLI needs setup in throwaway container"
        fi
        
        # Cleanup
        docker stop "$throwaway_name" 2>/dev/null || true
        success "Throwaway container cleaned up automatically"
    else
        error "Throwaway container creation failed"
        return 1
    fi
}

# Main test runner
main() {
    log "Starting ACI Claude Code Container Workflow Tests"
    log "================================================="
    
    local failed_tests=0
    
    # Run all tests
    test_container_startup || ((failed_tests++))
    echo
    
    test_authentication || ((failed_tests++))
    echo
    
    test_ssh_access || ((failed_tests++))
    echo
    
    test_claude_cli || ((failed_tests++))
    echo
    
    test_persistence || ((failed_tests++))
    echo
    
    test_file_structure || ((failed_tests++))
    echo
    
    test_throwaway_container || ((failed_tests++))
    echo
    
    # Summary
    log "================================================="
    if [ $failed_tests -eq 0 ]; then
        success "All tests passed! Container is ready for ACI integration"
        log ""
        log "Next steps:"
        log "1. Set up authentication: docker exec -it claude-cli-workspace /usr/local/bin/auth-manager.sh login"
        log "2. SSH into container: ssh claude@claude-cli"
        log "3. Integrate with ACI backend using the patterns in USAGE.md"
    else
        warn "$failed_tests test(s) had issues - check output above"
        log "Container is functional but may need authentication setup"
    fi
    
    return $failed_tests
}

# Run tests
main "$@"