#!/bin/bash

# Claude Code Container Startup Script
# Enhanced version of the original entrypoint with authentication management

USERNAME="claude"
CLAUDE_CONFIG_DIR="/home/$USERNAME/.claude"

log() {
    echo "[STARTUP] $1"
}

error() {
    echo "[ERROR] $1" >&2
}

# Fix directory permissions for volume mounts
fix_permissions() {
    log "Fixing directory permissions..."
    
    # Ensure claude user owns home directory and subdirectories
    sudo chown -R $USERNAME:$USERNAME /home/$USERNAME
    
    # Create .claude directory if it doesn't exist and ensure permissions
    mkdir -p "$CLAUDE_CONFIG_DIR"
    chown $USERNAME:$USERNAME "$CLAUDE_CONFIG_DIR"
    chmod 755 "$CLAUDE_CONFIG_DIR"
    
    # Create .claude/plugins directory
    mkdir -p "$CLAUDE_CONFIG_DIR/plugins"
    chown $USERNAME:$USERNAME "$CLAUDE_CONFIG_DIR/plugins"
    chmod 755 "$CLAUDE_CONFIG_DIR/plugins"
    
    # Create other necessary directories
    mkdir -p "/home/$USERNAME/.config/anthropic"
    chown $USERNAME:$USERNAME "/home/$USERNAME/.config/anthropic"
    chmod 755 "/home/$USERNAME/.config/anthropic"
}

# Set up git configuration if not already set
setup_git() {
    if [ -z "$(git config --global user.name)" ]; then
        log "Setting up default git configuration..."
        git config --global user.name "Claude Code User"
        git config --global user.email "claude@example.com"
        git config --global init.defaultBranch main
        git config --global core.pager delta
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global delta.light false
        git config --global merge.conflictstyle diff3
        git config --global diff.colorMoved default
        git config --global pull.rebase false
        git config --global push.default simple
        git config --global alias.st status
        git config --global alias.co checkout
        git config --global alias.br branch
        git config --global alias.ci commit
        git config --global alias.unstage "reset HEAD --"
        git config --global alias.last "log -1 HEAD"
        git config --global alias.visual "!gitk"
        log "Enhanced git configuration complete!"
    fi
}

# Create SSH users dynamically
setup_ssh_users() {
    log "Setting up SSH users..."
    if [ -f /usr/local/bin/create-ssh-user.sh ]; then
        sudo /usr/local/bin/create-ssh-user.sh || log "User creation script executed"
    fi
}

# Setup Tailscale
setup_tailscale() {
    log "Setting up Tailscale..."
    
    # Start Tailscale daemon
    log "Starting Tailscaled..."
    sudo mkdir -p /var/run/tailscale /var/lib/tailscale
    sudo tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &
    
    # Wait for daemon to start
    sleep 3
    
    # Connect to Tailscale with SSH enabled
    if [ -n "$TS_AUTHKEY" ] && [ "$TS_AUTHKEY" != "your_tailscale_auth_key_here" ]; then
        log "Connecting to Tailscale with SSH enabled..."
        sudo tailscale up --authkey="$TS_AUTHKEY" --ssh --hostname=claude-cli --reset || log "Tailscale connection attempted"
    else
        log "No valid Tailscale auth key provided"
    fi
}

# Setup SSH daemon
setup_ssh_daemon() {
    log "Setting up SSH daemon..."
    
    if ! pgrep sshd > /dev/null; then
        log "Starting SSH daemon..."
        sudo /usr/sbin/sshd -D &
    else
        log "SSH daemon already running"
    fi
}

# Setup Claude Code authentication
setup_claude_auth() {
    log "Setting up Claude Code authentication..."
    
    # Ensure the auth manager script is executable
    if [ -f /usr/local/bin/auth-manager.sh ]; then
        sudo chmod +x /usr/local/bin/auth-manager.sh
        
        # Run authentication setup
        /usr/local/bin/auth-manager.sh setup
        
        local auth_status=$?
        if [ $auth_status -eq 0 ]; then
            log "Claude Code authentication ready"
        else
            log "Claude Code authentication requires manual setup"
            log "Run: /usr/local/bin/auth-manager.sh login"
        fi
    else
        error "Authentication manager not found"
    fi
}

# Setup shell environment with simple, reliable configuration
setup_shell() {
    log "Setting up simple, reliable shell environment..."
    
    # Run the simple zsh setup script (no complex themes or wizards)
    if [ -f /usr/local/bin/simple-zsh-setup.sh ]; then
        /usr/local/bin/simple-zsh-setup.sh
    else
        error "Simple ZSH setup script not found"
        
        # Fallback minimal setup
        if ! grep -q "/home/$USERNAME/.npm-global/bin" /home/$USERNAME/.zshrc 2>/dev/null; then
            echo 'export PATH="/home/claude/.npm-global/bin:$PATH"' >> /home/$USERNAME/.zshrc
        fi
        
        if ! grep -q "alias claude=" /home/$USERNAME/.zshrc 2>/dev/null; then
            echo 'alias claude="/home/claude/.npm-global/bin/claude"' >> /home/$USERNAME/.zshrc
        fi
        
        # Disable any powerlevel10k wizard interruptions
        echo 'POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' >> /home/$USERNAME/.zshrc
    fi
    
    log "Simple shell environment configured - no wizards, just works!"
}

# Main startup sequence
main() {
    log "Claude Code CLI container starting up..."
    
    # Fix permissions first (for volume mounts)
    fix_permissions
    
    # Setup git
    setup_git
    
    # Setup SSH components
    setup_ssh_users
    setup_tailscale
    setup_ssh_daemon
    
    # Setup Claude Code
    setup_claude_auth
    setup_shell
    
    log "Claude Code CLI container ready!"
    log "Authentication status: $(if /usr/local/bin/auth-manager.sh check &>/dev/null; then echo 'Ready'; else echo 'Setup Required'; fi)"
    log "SSH access: ssh claude@claude-cli (via Tailscale) or docker exec"
    log "To start Claude: claude code"
    log ""
    
    # Execute the original command or start shell
    exec "$@"
}

# Run main function
main "$@"