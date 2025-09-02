.PHONY: help up down build rebuild login ssh logs logs-claude logs-tailscale logs-mcp mcp-start mcp-stop clean status start stop restart shell setup-ssh webui webui-logs webui-build webui-restart unified unified-logs

# Default target
help:
	@echo "Claude Code Unified Docker Environment (CLI + Web UI)"
	@echo ""
	@echo "Available targets:"
	@echo "  help         Show this help message"
	@echo ""  
	@echo "=== Standard Environment ==="
	@echo "  up           Start all services (build if needed)"
	@echo "  down         Stop all services"
	@echo "  build        Build the Claude CLI image"
	@echo "  rebuild      Rebuild the Claude CLI image from scratch"
	@echo "  login        Start OAuth device login flow for Claude Code CLI"
	@echo "  ssh          SSH into the Claude CLI container via Tailscale"
	@echo "  setup-ssh    Setup SSH key for passwordless access"
	@echo "  logs         Show logs for all services"
	@echo "  logs-claude  Show logs for Claude CLI container"
	@echo "  logs-mcp     Show logs for MCP toolkit container"
	@echo "  mcp-start    Start only MCP services"
	@echo "  mcp-stop     Stop MCP services"
	@echo "  status       Show container status"
	@echo "  clean        Remove all containers and volumes"
	@echo ""
	@echo "=== Unified Environment (CLI + Web UI) ==="
	@echo "  unified      Start unified environment with Web UI"
	@echo "  unified-logs Show logs for unified environment"
	@echo "  webui        Open Web UI in browser (after unified start)"
	@echo "  webui-build  Build Web UI images only"
	@echo "  webui-logs   Show Web UI specific logs"
	@echo "  webui-restart Restart only Web UI services"
	@echo ""
	@echo "Prerequisites:"
	@echo "  1. Copy .env.example to .env and set TS_AUTHKEY"
	@echo "  2. Run 'make up' to start services"
	@echo "  3. Run 'make login' to authenticate Claude Code CLI"
	@echo "  4. Use 'make ssh' to access the container via Tailscale"

up:
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found. Copy .env.example to .env and configure it."; \
		exit 1; \
	fi
	docker compose up -d --build

down:
	docker compose down

build:
	docker compose build claude-cli

rebuild:
	docker compose build --no-cache claude-cli

login:
	@echo "Starting Claude Code CLI OAuth login flow..."
	@echo "This will open a device code URL in your browser."
	@echo "If the URL doesn't open automatically, copy it from the output below."
	docker compose exec -it claude-cli claude code login

ssh:
	@echo "Attempting to SSH into Claude CLI container via Tailscale..."
	@echo "Make sure you're connected to your Tailscale network."
	@HOSTNAME=$$(docker compose ps tailscale --format "{{.Service}}" 2>/dev/null || echo "claude-cli"); \
	if command -v tailscale >/dev/null 2>&1; then \
		tailscale ssh $$HOSTNAME; \
	else \
		echo "Error: tailscale command not found on host."; \
		echo "Install Tailscale on your host machine or use 'docker compose exec -it claude-cli zsh'"; \
	fi

logs:
	docker compose logs -f

logs-claude:
	docker compose logs -f claude-cli

logs-tailscale:
	docker compose logs -f tailscale

logs-mcp:
	docker compose logs -f mcp-filesystem mcp-git

mcp-start:
	docker compose up -d mcp-filesystem mcp-git

mcp-stop:
	docker compose stop mcp-filesystem mcp-git

status:
	@echo "=== Container Status ==="
	docker compose ps
	@echo ""
	@echo "=== Volume Status ==="
	docker volume ls | grep devcon || echo "No devcon volumes found"
	@echo ""
	@echo "=== Health Checks ==="
	@docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"

clean:
	@echo "This will remove ALL containers and volumes. Are you sure? [y/N]"
	@read confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker compose down -v --remove-orphans; \
		docker system prune -f; \
		echo "Clean completed."; \
	else \
		echo "Clean cancelled."; \
	fi

# Aliases for convenience
start: up
stop: down
restart: down up
shell:
	docker compose exec -it claude-cli zsh

setup-ssh:
	@echo "Setting up SSH key for passwordless Tailscale SSH access..."
	./setup-ssh.sh

# =====================
# Unified Environment Commands (CLI + Web UI)
# =====================

unified:
	@if [ ! -f .env ]; then \
		echo "Error: .env file not found. Copy .env.example to .env and configure it."; \
		exit 1; \
	fi
	@echo "Starting unified Claude environment with Web UI..."
	docker compose -f docker-compose.unified.yml up -d --build

unified-logs:
	docker compose -f docker-compose.unified.yml logs -f

webui:
	@echo "Opening Claude Code Web UI..."
	@echo "Web UI should be available at:"
	@echo "  - Local: http://localhost"
	@echo "  - Tailscale: http://claude-proxy"
	@if command -v open >/dev/null 2>&1; then \
		open http://localhost; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open http://localhost; \
	else \
		echo "Please manually open http://localhost in your browser"; \
	fi

webui-build:
	@echo "Building Web UI services..."
	docker compose -f docker-compose.unified.yml build webui-backend webui-frontend nginx-proxy

webui-logs:
	docker compose -f docker-compose.unified.yml logs -f webui-backend webui-frontend nginx-proxy

webui-restart:
	@echo "Restarting Web UI services..."
	docker compose -f docker-compose.unified.yml restart webui-backend webui-frontend nginx-proxy

# Enhanced status for unified environment
unified-status:
	@echo "=== Unified Environment Status ==="
	docker compose -f docker-compose.unified.yml ps
	@echo ""
	@echo "=== Volume Status ==="
	docker volume ls | grep devcon || echo "No devcon volumes found"
	@echo ""
	@echo "=== Network Status ==="
	docker network ls | grep claude || echo "No claude networks found"
	@echo ""
	@echo "=== Health Checks ==="
	@docker compose -f docker-compose.unified.yml ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"