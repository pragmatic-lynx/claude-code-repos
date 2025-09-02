#!/bin/bash

# Fix ZSH configuration for persistent containers
# This script ensures zsh and powerlevel10k work correctly across container recreations

USERNAME="claude"
HOME_DIR="/home/$USERNAME"
OH_MY_ZSH_DIR="$HOME_DIR/.oh-my-zsh"
THEME_DIR="$OH_MY_ZSH_DIR/custom/themes/powerlevel10k"

log() {
    echo "[ZSH-FIX] $1"
}

# Ensure oh-my-zsh is properly set up
setup_oh_my_zsh() {
    if [ ! -d "$OH_MY_ZSH_DIR" ]; then
        log "Installing oh-my-zsh..."
        sudo -u $USERNAME sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
}

# Install powerlevel10k theme
setup_powerlevel10k() {
    if [ ! -d "$THEME_DIR" ]; then
        log "Installing powerlevel10k theme..."
        sudo -u $USERNAME git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$THEME_DIR"
    else
        log "Powerlevel10k theme already installed"
    fi
}

# Create or update .zshrc with proper configuration
setup_zshrc() {
    local ZSHRC="$HOME_DIR/.zshrc"
    
    if [ ! -f "$ZSHRC" ]; then
        log "Creating new .zshrc configuration..."
        
        cat > "$ZSHRC" << 'EOF'
export LANG='en_US.UTF-8'
export LANGUAGE='en_US:en'
export LC_ALL='en_US.UTF-8'
[ -z "$TERM" ] && export TERM=xterm

# Oh My Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
    git
    fzf
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
)

source $ZSH/oh-my-zsh.sh

# Enhanced shell configuration
export HISTFILE=/commandhistory/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_VERIFY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS

# FZF configuration
export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git/*'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"

# Key bindings
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down

# Direnv hook
eval "$(direnv hook zsh)"

# Modern CLI aliases
alias ls="eza --color=always --group-directories-first"
alias ll="eza -alF --color=always --group-directories-first"
alias la="eza -a --color=always --group-directories-first"
alias lt="eza -aT --color=always --group-directories-first"
alias cat="bat --paging=never"
alias grep="rg"
alias find="fd"
alias du="dust"

# Git aliases
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git pull"
alias gd="git diff"
alias gb="git branch"
alias gco="git checkout"
alias glog="git log --oneline --graph --decorate"

# Useful functions
mkcd() { mkdir -p "$1" && cd "$1" }
extract() { 
    case "$1" in 
        *.tar.gz) tar -xzf "$1";; 
        *.zip) unzip "$1";; 
        *) echo "Unknown format";; 
    esac 
}
gclone() { git clone "$1" && cd $(basename "$1" .git) }
ports() { ss -tuln | grep LISTEN }
weather() { curl -s "wttr.in/${1:-}" }

# Claude Code CLI path and alias
export PATH="/home/claude/.npm-global/bin:$PATH"
alias claude="/home/claude/.npm-global/bin/claude"

# Gemini CLI functions
gemini-login() { echo "Starting Gemini CLI OAuth login..." && gemini auth login --oauth }
gemini-status() { gemini auth status 2>/dev/null || echo "Not authenticated. Run: gemini-login" }
gemini-help() { 
    echo "Gemini CLI commands:"
    echo "  gemini-login  - OAuth login with Google account"
    echo "  gemini-status - Check authentication status"
    echo "  gemini chat   - Start interactive chat"
    echo "  gemini --help - Full help"
}
EOF
        
        log "Created comprehensive .zshrc configuration"
    else
        log "Updating existing .zshrc configuration..."
        
        # Ensure theme is set correctly
        if ! grep -q "ZSH_THEME=\"powerlevel10k/powerlevel10k\"" "$ZSHRC"; then
            sed -i 's/ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$ZSHRC"
        fi
        
        # Ensure PATH includes npm global bin
        if ! grep -q "/home/claude/.npm-global/bin" "$ZSHRC"; then
            echo 'export PATH="/home/claude/.npm-global/bin:$PATH"' >> "$ZSHRC"
        fi
        
        # Ensure claude alias exists
        if ! grep -q "alias claude=" "$ZSHRC"; then
            echo 'alias claude="/home/claude/.npm-global/bin/claude"' >> "$ZSHRC"
        fi
    fi
    
    # Set proper ownership
    chown -R $USERNAME:$USERNAME "$ZSHRC"
}

# Install required zsh plugins
setup_zsh_plugins() {
    local PLUGIN_DIR="$OH_MY_ZSH_DIR/custom/plugins"
    
    # zsh-autosuggestions
    if [ ! -d "$PLUGIN_DIR/zsh-autosuggestions" ]; then
        log "Installing zsh-autosuggestions..."
        sudo -u $USERNAME git clone https://github.com/zsh-users/zsh-autosuggestions "$PLUGIN_DIR/zsh-autosuggestions"
    fi
    
    # zsh-syntax-highlighting  
    if [ ! -d "$PLUGIN_DIR/zsh-syntax-highlighting" ]; then
        log "Installing zsh-syntax-highlighting..."
        sudo -u $USERNAME git clone https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGIN_DIR/zsh-syntax-highlighting"
    fi
    
    # zsh-history-substring-search
    if [ ! -d "$PLUGIN_DIR/zsh-history-substring-search" ]; then
        log "Installing zsh-history-substring-search..."
        sudo -u $USERNAME git clone https://github.com/zsh-users/zsh-history-substring-search "$PLUGIN_DIR/zsh-history-substring-search"
    fi
}

# Main setup function
main() {
    log "Setting up persistent zsh configuration..."
    
    setup_oh_my_zsh
    setup_powerlevel10k
    setup_zsh_plugins
    setup_zshrc
    
    # Set zsh as default shell
    if [ "$(getent passwd $USERNAME | cut -d: -f7)" != "/bin/zsh" ]; then
        log "Setting zsh as default shell for $USERNAME"
        chsh -s /bin/zsh $USERNAME
    fi
    
    log "ZSH configuration complete!"
    log "Theme: powerlevel10k"
    log "Plugins: git, fzf, autosuggestions, syntax-highlighting, history-substring-search"
}

# Run setup
main