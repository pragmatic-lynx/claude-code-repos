# CCR (Claude Code Repos) - Development Tasks

.PHONY: help install lint format check test clean

# Default target
help:
	@echo "CCR Development Commands:"
	@echo ""
	@echo "  install    Install CCR locally for development"
	@echo "  lint       Run shellcheck on all shell scripts"
	@echo "  format     Format shell scripts with shfmt"
	@echo "  check      Run both linting and formatting"
	@echo "  test       Run the test suite"
	@echo "  clean      Clean up temporary files"
	@echo ""
	@echo "Pre-commit setup:"
	@echo "  make check && git add -A && git commit"

# Install CCR for local development
install:
	@echo "Installing CCR for development..."
	./install.sh

# Run linting
lint:
	@echo "Running linting..."
	./scripts/lint.sh

# Format code
format:
	@echo "Formatting code..."
	./scripts/format.sh

# Run both linting and formatting
check: format lint
	@echo "✅ All checks passed!"

# Run tests
test:
	@echo "Running tests..."
	@if [ -d "test" ]; then \
		for test_file in test/test-*.sh; do \
			if [ -x "$$test_file" ]; then \
				echo "Running $$test_file..."; \
				$$test_file; \
			fi; \
		done; \
	else \
		echo "No test directory found. Create test/test-*.sh files."; \
	fi

# Clean up
clean:
	@echo "Cleaning up..."
	find . -name "*.tmp" -delete
	find . -name "*.log" -delete
	find . -name "*~" -delete