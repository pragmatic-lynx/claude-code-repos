#!/bin/bash

# Simple ZSH Setup - No configuration wizards, just works
# This replaces the complex powerlevel10k setup with a clean, functional theme

USERNAME="claude"
HOME_DIR="/home/$USERNAME"
OH_MY_ZSH_DIR="$HOME_DIR/.oh-my-zsh"

log() {
    echo "[ZSH-SIMPLE] $1"
}

# Install oh-my-zsh if not present
setup_oh_my_zsh() {
    if [ ! -d "$OH_MY_ZSH_DIR" ]; then
        log "Installing oh-my-zsh..."
        sudo -u $USERNAME sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        log "Oh-my-zsh already installed"
    fi
}

# Install useful plugins
setup_plugins() {
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
}

# Create a clean, functional .zshrc without complex themes
create_simple_zshrc() {
    local ZSHRC="$HOME_DIR/.zshrc"
    
    log "Creating simple, functional .zshrc..."
    
    cat > "$ZSHRC" << 'EOF'
# Simple ZSH Configuration for Claude Code Container
# No wizards, no complex themes, just works

export LANG='en_US.UTF-8'
export LANGUAGE='en_US:en'
export LC_ALL='en_US.UTF-8'
export TERM=${TERM:-xterm-256color}

# Oh My Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"

# Use a simple, reliable theme
ZSH_THEME="robbyrussell"

# Load useful plugins
plugins=(
    git
    docker
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# History configuration
export HISTFILE=/commandhistory/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_VERIFY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS

# Modern CLI tools configuration
if command -v eza &> /dev/null; then
    alias ls="eza --color=always --group-directories-first"
    alias ll="eza -alF --color=always --group-directories-first"
    alias la="eza -a --color=always --group-directories-first"
    alias lt="eza -aT --color=always --group-directories-first"
fi

if command -v bat &> /dev/null; then
    alias cat="bat --paging=never"
fi

if command -v rg &> /dev/null; then
    alias grep="rg"
fi

if command -v fd &> /dev/null; then
    alias find="fd"
fi

if command -v dust &> /dev/null; then
    alias du="dust"
fi

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

# Docker aliases
alias dps="docker ps"
alias dls="docker images"
alias dex="docker exec -it"

# Useful functions
mkcd() { mkdir -p "$1" && cd "$1" }

extract() {
    case "$1" in
        *.tar.gz) tar -xzf "$1";;
        *.tar.bz2) tar -xjf "$1";;
        *.zip) unzip "$1";;
        *.tar) tar -xf "$1";;
        *.gz) gunzip "$1";;
        *) echo "Unknown format: $1";;
    esac
}

gclone() {
    git clone "$1" && cd $(basename "$1" .git)
}

ports() {
    ss -tuln | grep LISTEN
}

# Claude Code CLI configuration
export PATH="/home/claude/.npm-global/bin:$PATH"
alias claude="/home/claude/.npm-global/bin/claude"

# Welcome message
claude_welcome() {
    echo ""
    echo "🤖 Claude Code CLI Container Ready!"
    echo ""
    echo "Quick commands:"
    echo "  claude --version     # Check Claude CLI"
    echo "  claude -p 'prompt'   # Ask Claude something"
    echo "  ll                   # List files (modern ls)"
    echo "  gs                   # Git status"
    echo ""
    echo "Authentication: /usr/local/bin/auth-manager.sh check"
    echo "SSH Test: ssh claude@claude-cli"
    echo ""
}

# Show welcome on interactive shells
if [[ $- == *i* ]] && [[ -z $CLAUDE_WELCOME_SHOWN ]]; then
    claude_welcome
    export CLAUDE_WELCOME_SHOWN=1
fi

# Set a clean, informative prompt
PROMPT='%F{cyan}[claude@%m]%f %F{yellow}%~%f %F{green}$(git_prompt_info)%f
%F{blue}➜%f '

# FZF configuration (if available)
if command -v fzf &> /dev/null; then
    export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git/*'" 2>/dev/null || export FZF_DEFAULT_COMMAND="find . -type f"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
fi

# Direnv hook (if available)
if command -v direnv &> /dev/null; then
    eval "$(direnv hook zsh)"
fi
EOF
    
    # Set proper ownership
    chown $USERNAME:$USERNAME "$ZSHRC"
    chmod 644 "$ZSHRC"
    
    log "Created simple .zshrc configuration"
}

# Set zsh as default shell
set_default_shell() {
    if [ "$(getent passwd $USERNAME | cut -d: -f7)" != "/bin/zsh" ]; then
        log "Setting zsh as default shell for $USERNAME"
        chsh -s /bin/zsh $USERNAME
    fi
}

# Main setup function
main() {
    log "Setting up simple, reliable zsh configuration..."
    
    setup_oh_my_zsh
    setup_plugins
    create_simple_zshrc
    set_default_shell
    
    log "Simple zsh setup complete!"
    log "Theme: robbyrussell (clean and reliable)"
    log "Plugins: git, docker, autosuggestions, syntax-highlighting"
    log "No configuration wizards - just works!"
}

# Run setup
main