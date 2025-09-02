#!/bin/bash

# Claude Code Repository Manager - Shell Aliases
# Source this file to add convenient aliases for repo management

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_MANAGER="${SCRIPT_DIR}/repo-manager.sh"

# Check if repo-manager.sh exists
if [ ! -f "$REPO_MANAGER" ]; then
    echo "Error: repo-manager.sh not found at $REPO_MANAGER"
    return 1
fi

# Main alias for repo management
alias claude-repo="$REPO_MANAGER"

# Short aliases for common operations
alias cr-init="$REPO_MANAGER init"
alias cr-clone="$REPO_MANAGER clone"
alias cr-start="$REPO_MANAGER start"
alias cr-stop="$REPO_MANAGER stop"
alias cr-list="$REPO_MANAGER list"

# The most important alias - quick repo access
# Usage: cr <repo-name>
cr() {
    local repo_name="$1"
    
    if [ -z "$repo_name" ]; then
        echo "Usage: cr <repo-name>"
        echo "Available repos:"
        "$REPO_MANAGER" list
        return 1
    fi
    
    # Execute interactive shell in repo container
    "$REPO_MANAGER" exec "$repo_name"
}

# Quick repo access with command execution
# Usage: crc <repo-name> <command>
crc() {
    local repo_name="$1"
    shift
    local command="$@"
    
    if [ -z "$repo_name" ] || [ -z "$command" ]; then
        echo "Usage: crc <repo-name> <command>"
        return 1
    fi
    
    # Execute command in repo container
    "$REPO_MANAGER" exec "$repo_name" "$command"
}

# Quick Claude Code command in repo
# Usage: claude-in <repo-name> <claude-args>
claude-in() {
    local repo_name="$1"
    shift
    local claude_args="$@"
    
    if [ -z "$repo_name" ]; then
        echo "Usage: claude-in <repo-name> <claude-args>"
        return 1
    fi
    
    # Run Claude Code CLI in repo container
    crc "$repo_name" "claude $claude_args"
}

# Tab completion for repo names
_claude_repo_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local script_dir="$(dirname "$REPO_MANAGER")"
    
    # Get repo names from compose files
    local repos=$(ls "$script_dir"/docker-compose.*.yml 2>/dev/null | sed -n 's/.*docker-compose\.\(.*\)\.yml/\1/p' | sort)
    
    COMPREPLY=($(compgen -W "$repos" -- "$cur"))
}

# Set up tab completion
if command -v complete >/dev/null 2>&1; then
    complete -F _claude_repo_complete cr
    complete -F _claude_repo_complete crc
    complete -F _claude_repo_complete claude-in
    complete -F _claude_repo_complete cr-start
    complete -F _claude_repo_complete cr-stop
fi

# Installation function
install_aliases() {
    local shell_rc=""
    local install_line="source $SCRIPT_DIR/aliases.sh"
    
    # Detect shell and RC file
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    else
        echo "Unsupported shell. Please manually add to your shell RC file:"
        echo "$install_line"
        return 1
    fi
    
    # Check if already installed
    if grep -q "source.*aliases.sh" "$shell_rc" 2>/dev/null; then
        echo "Claude Code repo aliases already installed in $shell_rc"
        return 0
    fi
    
    # Add to shell RC file
    echo "" >> "$shell_rc"
    echo "# Claude Code Repository Manager aliases" >> "$shell_rc"
    echo "$install_line" >> "$shell_rc"
    
    echo "Claude Code repo aliases installed to $shell_rc"
    echo "Restart your shell or run: source $shell_rc"
}

# Show available aliases
show_aliases() {
    cat << 'EOF'
Claude Code Repository Manager - Available Aliases:

MAIN COMMANDS:
    claude-repo <cmd>    Full repo manager (same as ./repo-manager.sh)

QUICK ACCESS:
    cr <repo>           Enter interactive shell in repo container
    crc <repo> <cmd>    Execute command in repo container
    claude-in <repo>    Run Claude Code CLI in repo container

SHORT ALIASES:
    cr-init <repo>      Initialize container for existing repo
    cr-clone <repo>     Clone from Gitea and create container
    cr-start <repo>     Start repo container
    cr-stop <repo>      Stop repo container  
    cr-list             List all repo containers

EXAMPLES:
    cr my-frontend              # Enter my-frontend container
    crc api-service "npm test"  # Run tests in api-service
    claude-in my-app --help     # Run claude --help in my-app container

INSTALLATION:
    source aliases.sh           # Load aliases in current shell
    aliases.sh install         # Add to shell RC file permanently

EOF
}

# Handle direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Script is being executed directly
    case "${1:-}" in
        "install")
            install_aliases
            ;;
        "show"|"help"|"")
            show_aliases
            ;;
        *)
            echo "Usage: aliases.sh [install|show|help]"
            exit 1
            ;;
    esac
else
    # Script is being sourced
    echo "Claude Code repo aliases loaded! Use 'show_aliases' to see available commands."
fi