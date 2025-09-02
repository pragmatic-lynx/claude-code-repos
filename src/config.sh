#!/bin/bash
# CCR Configuration Management

CCR_CONFIG_FILE="$HOME/.ccr/config"

# Default configuration values
CCR_DEFAULT_GIT_PROVIDER="github"
CCR_DEFAULT_GITEA_HOST=""
CCR_DEFAULT_GITEA_USER=""
CCR_DEFAULT_USE_TAILSCALE="false"
CCR_DEFAULT_TAILSCALE_AUTHKEY=""

# Initialize configuration file if it doesn't exist
ccr_init_config() {
    mkdir -p "$(dirname "$CCR_CONFIG_FILE")"
    
    if [ ! -f "$CCR_CONFIG_FILE" ]; then
        cat > "$CCR_CONFIG_FILE" << EOF
# CCR Configuration File
# This file contains your CCR settings

# Git provider: "github" or "gitea"
GIT_PROVIDER="$CCR_DEFAULT_GIT_PROVIDER"

# Gitea settings (only used if GIT_PROVIDER="gitea")
GITEA_HOST="$CCR_DEFAULT_GITEA_HOST"
GITEA_USER="$CCR_DEFAULT_GITEA_USER"

# Tailscale settings
USE_TAILSCALE="$CCR_DEFAULT_USE_TAILSCALE"
TAILSCALE_AUTHKEY="$CCR_DEFAULT_TAILSCALE_AUTHKEY"
EOF
    fi
}

# Load configuration
ccr_load_config() {
    ccr_init_config
    # shellcheck source=/dev/null
    source "$CCR_CONFIG_FILE"
    
    # Set defaults if not specified
    GIT_PROVIDER="${GIT_PROVIDER:-$CCR_DEFAULT_GIT_PROVIDER}"
    GITEA_HOST="${GITEA_HOST:-$CCR_DEFAULT_GITEA_HOST}"
    GITEA_USER="${GITEA_USER:-$CCR_DEFAULT_GITEA_USER}"
    USE_TAILSCALE="${USE_TAILSCALE:-$CCR_DEFAULT_USE_TAILSCALE}"
    TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY:-$CCR_DEFAULT_TAILSCALE_AUTHKEY}"
}

# Get configuration value
ccr_get_config() {
    local key="$1"
    ccr_load_config
    
    case "$key" in
        "git.provider") echo "$GIT_PROVIDER" ;;
        "gitea.host") echo "$GITEA_HOST" ;;
        "gitea.user") echo "$GITEA_USER" ;;
        "tailscale.enabled") echo "$USE_TAILSCALE" ;;
        "tailscale.authkey") echo "$TAILSCALE_AUTHKEY" ;;
        *) echo "" ;;
    esac
}

# Set configuration value
ccr_set_config() {
    local key="$1"
    local value="$2"
    
    ccr_init_config
    
    case "$key" in
        "git.provider")
            if [ "$value" != "github" ] && [ "$value" != "gitea" ]; then
                echo "Error: git.provider must be 'github' or 'gitea'" >&2
                return 1
            fi
            sed -i "s/^GIT_PROVIDER=.*/GIT_PROVIDER=\"$value\"/" "$CCR_CONFIG_FILE"
            ;;
        "gitea.host")
            sed -i "s/^GITEA_HOST=.*/GITEA_HOST=\"$value\"/" "$CCR_CONFIG_FILE"
            ;;
        "gitea.user")
            sed -i "s/^GITEA_USER=.*/GITEA_USER=\"$value\"/" "$CCR_CONFIG_FILE"
            ;;
        "tailscale.enabled")
            if [ "$value" != "true" ] && [ "$value" != "false" ]; then
                echo "Error: tailscale.enabled must be 'true' or 'false'" >&2
                return 1
            fi
            sed -i "s/^USE_TAILSCALE=.*/USE_TAILSCALE=\"$value\"/" "$CCR_CONFIG_FILE"
            ;;
        "tailscale.authkey")
            sed -i "s/^TAILSCALE_AUTHKEY=.*/TAILSCALE_AUTHKEY=\"$value\"/" "$CCR_CONFIG_FILE"
            ;;
        *)
            echo "Error: Unknown configuration key: $key" >&2
            return 1
            ;;
    esac
}

# Show all configuration
ccr_show_config() {
    ccr_load_config
    
    echo "CCR Configuration:"
    echo ""
    echo "Git Provider Settings:"
    echo "  git.provider = $GIT_PROVIDER"
    echo "  gitea.host = $GITEA_HOST"
    echo "  gitea.user = $GITEA_USER"
    echo ""
    echo "Tailscale Settings:"
    echo "  tailscale.enabled = $USE_TAILSCALE"
    if [ "$USE_TAILSCALE" = "true" ]; then
        if [ -n "$TAILSCALE_AUTHKEY" ]; then
            echo "  tailscale.authkey = [SET]"
        else
            echo "  tailscale.authkey = [NOT SET]"
        fi
    fi
}

# Interactive configuration setup
ccr_config_wizard() {
    echo "CCR Configuration Wizard"
    echo "========================"
    echo ""
    
    # Git provider
    echo "Git Provider Configuration:"
    echo "1) GitHub (github.com)"
    echo "2) Gitea (self-hosted)"
    echo ""
    read -p "Select git provider [1]: " git_choice
    
    case "$git_choice" in
        2|gitea|Gitea)
            ccr_set_config "git.provider" "gitea"
            echo ""
            read -p "Enter your Gitea host (e.g., gitea.example.com): " gitea_host
            read -p "Enter your Gitea username: " gitea_user
            ccr_set_config "gitea.host" "$gitea_host"
            ccr_set_config "gitea.user" "$gitea_user"
            ;;
        *|1|github|GitHub)
            ccr_set_config "git.provider" "github"
            ;;
    esac
    
    # Tailscale
    echo ""
    echo "Tailscale Configuration:"
    read -p "Enable Tailscale networking? [y/N]: " tailscale_choice
    
    case "$tailscale_choice" in
        y|Y|yes|Yes)
            ccr_set_config "tailscale.enabled" "true"
            echo ""
            read -p "Enter Tailscale auth key (optional): " ts_authkey
            if [ -n "$ts_authkey" ]; then
                ccr_set_config "tailscale.authkey" "$ts_authkey"
            fi
            ;;
        *)
            ccr_set_config "tailscale.enabled" "false"
            ;;
    esac
    
    echo ""
    echo "Configuration saved!"
    echo ""
    ccr_show_config
}

# Export functions for use in other scripts
export -f ccr_init_config ccr_load_config ccr_get_config ccr_set_config ccr_show_config ccr_config_wizard