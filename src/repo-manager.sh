#!/bin/bash

# Claude Code Repo Manager
# Manages isolated Claude Code containers for individual repositories

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_BASE_DIR="$HOME/repos"

# Load configuration system
source "$SCRIPT_DIR/config.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[REPO-MGR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[REPO-MGR]${NC} $1"
}

error() {
    echo -e "${RED}[REPO-MGR]${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[REPO-MGR]${NC} $1"
}

# Ensure repos directory exists
ensure_repos_dir() {
    if [ ! -d "$REPOS_BASE_DIR" ]; then
        log "Creating repos directory: $REPOS_BASE_DIR"
        mkdir -p "$REPOS_BASE_DIR"
    fi
}

# Generate docker-compose config for a repo
generate_compose_config() {
    local repo_name="$1"
    local repo_path="$2"
    local container_name="claude-${repo_name}"
    
    # Load configuration
    ccr_load_config
    
    # Determine git provider settings
    local git_env=""
    if [ "$GIT_PROVIDER" = "gitea" ]; then
        git_env="
      - GITEA_URL=${GITEA_HOST}
      - GITEA_USER=${GITEA_USER}"
    fi
    
    # Tailscale configuration
    local tailscale_volumes=""
    local tailscale_env=""
    local tailscale_config=""
    local tailscale_caps=""
    local tailscale_devices=""
    
    if [ "$USE_TAILSCALE" = "true" ]; then
        tailscale_volumes="
      - tailscale_state_${repo_name}:/var/lib/tailscale
      - ./config/tailscale:/config"
        tailscale_env="
      - TS_AUTHKEY=${TAILSCALE_AUTHKEY}"
        tailscale_caps="
    cap_add:
      - NET_ADMIN
      - SYS_MODULE"
        tailscale_devices="
    devices:
      - /dev/net/tun:/dev/net/tun"
    fi
    
    cat > "$SCRIPT_DIR/../containers/docker-compose.${repo_name}.yml" << EOF
version: '3.8'

services:
  claude-${repo_name}:
    build:
      context: .
      dockerfile: Dockerfile.claude
    container_name: ${container_name}
    hostname: claude-${repo_name}
    environment:
      - TZ=UTC
      - ANTHROPIC_LOG_LEVEL=info
      - REPO_NAME=${repo_name}${git_env}${tailscale_env}
    volumes:
      - anthropic_config:/home/claude/.config/anthropic
      - ${repo_path}:/workspace
      - command_history_${repo_name}:/commandhistory
      - claude_home:/home/claude
      - ./config/claude:/home/claude/.claude${tailscale_volumes}
    working_dir: /workspace${tailscale_devices}${tailscale_caps}
    restart: unless-stopped
    tty: true
    stdin_open: true
    networks:
      - claude-${repo_name}-network

  # MCP Filesystem Server for ${repo_name}
  mcp-filesystem-${repo_name}:
    image: node:20-slim
    container_name: mcp-filesystem-${repo_name}
    networks:
      - claude-${repo_name}-network
    environment:
      - MCP_LOG_LEVEL=info
    volumes:
      - ${repo_path}:/workspace:ro
    working_dir: /workspace
    command: >
      sh -c "npm install -g @modelcontextprotocol/server-filesystem &&
             npx @modelcontextprotocol/server-filesystem /workspace"
    restart: unless-stopped

  # MCP Git Server for ${repo_name}
  mcp-git-${repo_name}:
    image: python:3.11-slim
    container_name: mcp-git-${repo_name}
    networks:
      - claude-${repo_name}-network
    environment:
      - MCP_LOG_LEVEL=info
    volumes:
      - ${repo_path}:/workspace
    working_dir: /workspace
    command: >
      sh -c "apt update && apt install -y git &&
             pip install mcp-server-git &&
             cd /workspace && 
             if [ ! -d .git ]; then 
               git init && 
               if [ '$GIT_PROVIDER' = 'gitea' ] && [ -n '$GITEA_HOST' ] && [ -n '$GITEA_USER' ]; then
                 git config user.name '$GITEA_USER' && 
                 git config user.email '$GITEA_USER@$GITEA_HOST' &&
                 git config credential.helper 'store --file=/workspace/.git-credentials'
               else
                 git config user.name 'claude' &&
                 git config user.email 'claude@github.com'
               fi &&
               git branch -M main
             fi &&
             python -m mcp_server_git --repository /workspace"
    restart: unless-stopped

networks:
  claude-${repo_name}-network:
    driver: bridge
    internal: false

volumes:
  anthropic_config:
    external: true
  command_history_${repo_name}:
    driver: local
  claude_home:
    external: true$([ "$USE_TAILSCALE" = "true" ] && echo "
  tailscale_state_${repo_name}:
    driver: local")
EOF
}

# Initialize container for existing local repo
init_repo() {
    local repo_name="$1"
    
    if [ -z "$repo_name" ]; then
        error "Repository name is required. Usage: claude-repo init <repo-name>"
    fi
    
    local repo_path="${REPOS_BASE_DIR}/${repo_name}"
    
    if [ ! -d "$repo_path" ]; then
        error "Repository directory does not exist: $repo_path"
    fi
    
    log "Initializing Claude Code container for repo: $repo_name"
    log "Repository path: $repo_path"
    
    # Generate docker-compose config
    generate_compose_config "$repo_name" "$repo_path"
    
    # Start the container
    log "Starting container for $repo_name..."
    cd "$SCRIPT_DIR/../containers"
    docker compose -f "docker-compose.${repo_name}.yml" up -d
    
    # Wait for container to be ready
    log "Waiting for container to initialize..."
    sleep 5
    
    # Configure git in the container
    configure_git_in_container "$repo_name"
    
    info "Repository container '$repo_name' is ready!"
    info "Access with: docker exec -it claude-${repo_name} sudo -u claude /bin/zsh"
    info "Or use: cr $repo_name (after installing aliases)"
}

# Clone repo from Gitea and create container
clone_repo() {
    local repo_name="$1"
    
    if [ -z "$repo_name" ]; then
        error "Repository name is required. Usage: claude-repo clone <repo-name>"
    fi
    
    ensure_repos_dir
    
    local repo_path="${REPOS_BASE_DIR}/${repo_name}"
    local clone_url="https://${GITEA_USER}:${GITEA_TOKEN}@${GITEA_URL}/${GITEA_USER}/${repo_name}.git"
    
    if [ -d "$repo_path" ]; then
        error "Repository directory already exists: $repo_path"
    fi
    
    log "Cloning repository from Gitea: $repo_name"
    
    # Clone the repository
    cd "$REPOS_BASE_DIR"
    git clone "$clone_url" "$repo_name" || error "Failed to clone repository"
    
    # Initialize container for the cloned repo
    init_repo "$repo_name"
}

# Configure git credentials in container
configure_git_in_container() {
    local repo_name="$1"
    local container_name="claude-${repo_name}"
    
    log "Configuring git credentials in container: $container_name"
    
    # Configure git user
    docker exec "$container_name" sudo -u claude git config --global user.name "$GITEA_USER"
    docker exec "$container_name" sudo -u claude git config --global user.email "${GITEA_USER}@${GITEA_URL}"
    
    # Configure git credential helper
    docker exec "$container_name" sudo -u claude git config --global credential.helper 'store --file=/home/claude/.git-credentials'
    
    # Store credentials
    docker exec "$container_name" sudo -u claude bash -c "echo 'https://${GITEA_USER}:${GITEA_TOKEN}@${GITEA_URL}' > /home/claude/.git-credentials"
    docker exec "$container_name" sudo -u claude chmod 600 /home/claude/.git-credentials
    
    # Set default branch to main
    docker exec "$container_name" sudo -u claude git config --global init.defaultBranch main
}

# Start existing repo container
start_repo() {
    local repo_name="$1"
    
    if [ -z "$repo_name" ]; then
        error "Repository name is required. Usage: claude-repo start <repo-name>"
    fi
    
    local compose_file="${SCRIPT_DIR}/../containers/docker-compose.${repo_name}.yml"
    
    if [ ! -f "$compose_file" ]; then
        error "No container configuration found for repo: $repo_name. Run 'claude-repo init $repo_name' first."
    fi
    
    log "Starting container for repo: $repo_name"
    cd "$SCRIPT_DIR/../containers"
    docker compose -f "$(basename "$compose_file")" up -d
    
    info "Container for '$repo_name' is running!"
}

# Stop repo container
stop_repo() {
    local repo_name="$1"
    
    if [ -z "$repo_name" ]; then
        error "Repository name is required. Usage: claude-repo stop <repo-name>"
    fi
    
    local compose_file="${SCRIPT_DIR}/../containers/docker-compose.${repo_name}.yml"
    
    if [ ! -f "$compose_file" ]; then
        error "No container configuration found for repo: $repo_name"
    fi
    
    log "Stopping container for repo: $repo_name"
    cd "$SCRIPT_DIR/../containers"
    docker compose -f "$(basename "$compose_file")" down
    
    info "Container for '$repo_name' stopped."
}

# Execute command in repo container
exec_repo() {
    local repo_name="$1"
    shift # Remove repo_name from arguments
    local cmd="${@:-sudo -u claude /bin/zsh}"
    
    if [ -z "$repo_name" ]; then
        error "Repository name is required. Usage: claude-repo exec <repo-name> [command]"
    fi
    
    local container_name="claude-${repo_name}"
    
    # Check if container is running
    if ! docker ps | grep -q "$container_name"; then
        warn "Container '$container_name' is not running. Starting it..."
        start_repo "$repo_name"
        sleep 3
    fi
    
    # Execute command in container
    docker exec -it "$container_name" $cmd
}

# List all repo containers
list_repos() {
    log "Repository containers:"
    echo
    
    # List compose files
    if ls "${SCRIPT_DIR}/../containers"/docker-compose.*.yml 1> /dev/null 2>&1; then
        for compose_file in "${SCRIPT_DIR}/../containers"/docker-compose.*.yml; do
            local filename=$(basename "$compose_file")
            if [[ "$filename" =~ docker-compose\.(.*)\.yml ]]; then
                local repo_name="${BASH_REMATCH[1]}"
                local container_name="claude-${repo_name}"
                local status="stopped"
                
                if docker ps | grep -q "$container_name"; then
                    status="${GREEN}running${NC}"
                else
                    status="${RED}stopped${NC}"
                fi
                
                printf "  %-20s %s\n" "$repo_name" "$status"
            fi
        done
    else
        info "No repository containers found."
        info "Create one with: claude-repo init <repo-name> or claude-repo clone <repo-name>"
    fi
}

# Show help
show_help() {
    cat << EOF
Claude Code Repository Manager

USAGE:
    claude-repo <command> [arguments]

COMMANDS:
    init <repo-name>     Initialize container for existing local repo
    clone <repo-name>    Clone repo from Gitea and create container
    start <repo-name>    Start existing repo container
    stop <repo-name>     Stop repo container
    exec <repo-name>     Execute command in repo container (default: zsh)
    list                 List all repo containers and their status
    help                 Show this help message

EXAMPLES:
    claude-repo init my-frontend        # Create container for ~/repos/my-frontend
    claude-repo clone api-service       # Clone from Gitea and create container
    claude-repo exec my-frontend        # Enter interactive shell in container
    claude-repo exec my-frontend "claude --version"  # Run command in container

CONFIGURATION:
    Repos directory:  $REPOS_BASE_DIR
    Gitea URL:        $GITEA_URL
    Gitea user:       $GITEA_USER

EOF
}

# Main command dispatcher
main() {
    local command="$1"
    shift || true
    
    case "$command" in
        "init")
            init_repo "$@"
            ;;
        "clone")
            clone_repo "$@"
            ;;
        "start")
            start_repo "$@"
            ;;
        "stop")
            stop_repo "$@"
            ;;
        "exec")
            exec_repo "$@"
            ;;
        "list")
            list_repos
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            error "Unknown command: $command. Use 'claude-repo help' for usage information."
            ;;
    esac
}

# Run main function with all arguments
main "$@"