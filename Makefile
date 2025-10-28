.PHONY: setup test test-quick clean help install-hooks

# Default target
.DEFAULT_GOAL := help

setup: ## Install tools and configure pre-commit hooks
	@echo "Installing Gruntwork tools..."
	@./scripts/install-tools.sh
	@echo "Installing pre-commit hooks..."
	@$(HOME)/Library/Python/3.10/bin/pre-commit install
	@echo "✅ Setup complete!"

install-hooks: ## Install pre-commit hooks only
	@$(HOME)/Library/Python/3.10/bin/pre-commit install
	@echo "✅ Pre-commit hooks installed"

test: ## Run all tests (pre-commit + full terratest suite)
	@echo "Running pre-commit checks..."
	@$(HOME)/Library/Python/3.10/bin/pre-commit run --all-files
	@echo "Running Terratest..."
	@cd test && go test -v -timeout 60m
	@echo "✅ All tests passed!"

test-quick: ## Run quick tests only (pre-commit + short terratest)
	@echo "Running pre-commit checks..."
	@$(HOME)/Library/Python/3.10/bin/pre-commit run --all-files
	@echo "Running quick Terratest..."
	@cd test && go test -v -short -timeout 10m
	@echo "✅ Quick tests passed!"

test-precommit: ## Run pre-commit checks only
	@$(HOME)/Library/Python/3.10/bin/pre-commit run --all-files

test-go: ## Run terratest only
	@cd test && go test -v -timeout 60m

clean: ## Clean up test artifacts
	@echo "Cleaning up test artifacts..."
	@find . -type f -name "terraform.tfstate*" -delete
	@find . -type f -name ".terraform.lock.hcl" -delete
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find test -type f -name "*.test" -delete
	@echo "✅ Cleanup complete"

fmt: ## Format all terraform/terragrunt files
	@echo "Formatting Terraform files..."
	@terraform fmt -recursive .
	@echo "Formatting Terragrunt files..."
	@terragrunt hclfmt
	@echo "✅ Formatting complete"

lint: ## Lint terraform files
	@echo "Linting Terraform files..."
	@tflint --recursive
	@echo "✅ Linting complete"

help: ## Show this help message
	@echo "LightWave Infrastructure Catalog - Make Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make <target>"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
