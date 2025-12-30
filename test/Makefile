# Django Terratest Makefile
# Quick commands for running infrastructure tests

.PHONY: help test test-all test-django test-django-module test-django-unit test-django-integration test-django-performance clean deps

# Default AWS profile
AWS_PROFILE ?= lightwave-admin-new
export AWS_PROFILE

# Default timeout for tests
TIMEOUT ?= 60m

help: ## Show this help message
	@echo "Django Infrastructure Testing"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-30s %s\n", $$1, $$2}'

deps: ## Install test dependencies
	@echo "Installing Go dependencies..."
	go mod download
	go mod tidy
	@echo "✅ Dependencies installed"

test-all: ## Run all tests (WARNING: expensive, ~$2)
	@echo "Running ALL tests..."
	@echo "⚠️  This will deploy real infrastructure and cost money"
	@read -p "Continue? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		go test -v -timeout $(TIMEOUT) ./...; \
	fi

test-django: test-django-unit ## Run Django-specific tests (alias for test-django-unit)

test-django-module: ## Validate Django module (fast, free)
	@echo "Testing Django Fargate module..."
	go test -v -timeout 10m ./terragrunt/units -run TestDjangoModuleMinimal

test-django-unit: ## Deploy and test Django service (~5 min, ~$0.50)
	@echo "Testing Django Fargate unit deployment..."
	@echo "⚠️  This will deploy real infrastructure"
	@read -p "Continue? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		go test -v -timeout 30m ./terragrunt/units -run TestUnitDjangoFargateService; \
	fi

test-django-integration: ## Run full Django integration tests (~8 min, ~$0.70)
	@echo "Running Django integration tests..."
	@echo "⚠️  This will deploy real infrastructure"
	@read -p "Continue? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		go test -v -timeout 30m -run TestDjangoIntegrationFull; \
	fi

test-django-performance: ## Run Django performance tests (~4 min, ~$0.30)
	@echo "Running Django performance tests..."
	@echo "⚠️  This will deploy real infrastructure"
	@read -p "Continue? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		go test -v -timeout 30m -run TestDjangoContainerStartupTime; \
	fi

test-quick: test-django-module ## Run quick tests only (module validation)

clean: ## Clean test cache and artifacts
	@echo "Cleaning test cache..."
	go clean -testcache
	rm -f test-output.log
	@echo "✅ Test cache cleaned"

verify-aws: ## Verify AWS credentials
	@echo "Verifying AWS credentials..."
	@aws sts get-caller-identity --profile $(AWS_PROFILE) || (echo "❌ AWS credentials not configured" && exit 1)
	@echo "✅ AWS credentials verified"

check-tools: ## Verify required tools are installed
	@echo "Checking required tools..."
	@which go > /dev/null || (echo "❌ Go not installed" && exit 1)
	@echo "  ✅ Go installed: $$(go version)"
	@which terragrunt > /dev/null || (echo "❌ Terragrunt not installed" && exit 1)
	@echo "  ✅ Terragrunt installed: $$(terragrunt --version | head -n 1)"
	@which aws > /dev/null || (echo "❌ AWS CLI not installed" && exit 1)
	@echo "  ✅ AWS CLI installed: $$(aws --version)"

setup: check-tools verify-aws deps ## Complete setup (check tools, verify AWS, install deps)
	@echo ""
	@echo "✅ Setup complete! Ready to run tests."
	@echo ""
	@echo "Quick start:"
	@echo "  make test-django-module    # Free, validates Terraform"
	@echo "  make test-django-unit      # ~$0.50, deploys and tests"
	@echo "  make test-django-integration  # ~$0.70, full API tests"

# Development helpers
fmt: ## Format Go code
	go fmt ./...

vet: ## Run go vet
	go vet ./...

lint: fmt vet ## Run formatters and linters
	@echo "✅ Code formatted and vetted"

# Module-specific tests (no deployment, fast)
test-modules-minimal: ## Test all modules without deployment (fast, free)
	@echo "Testing module configurations..."
	go test -v -timeout 10m ./modules -run "Minimal"

test-ecs-module: ## Test ECS Fargate module (deploys, ~$1)
	@echo "Testing ECS Fargate module..."
	@echo "⚠️  This will deploy real infrastructure"
	@read -p "Continue? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		go test -v -timeout 30m ./modules -run TestECSFargateServiceModule; \
	fi

test-postgresql-module: ## Test PostgreSQL RDS module (deploys, ~$2, slow)
	@echo "Testing PostgreSQL RDS module..."
	@echo "⚠️  This will deploy real infrastructure (takes 10-15 minutes)"
	@read -p "Continue? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		go test -v -timeout 45m ./modules -run TestPostgreSQLModule; \
	fi

test-redis-module: ## Test Redis ElastiCache module (deploys, ~$1)
	@echo "Testing Redis ElastiCache module..."
	@echo "⚠️  This will deploy real infrastructure"
	@read -p "Continue? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		go test -v -timeout 30m ./modules -run TestRedisModule; \
	fi

test-core-modules: ## Test ECS, PostgreSQL, and Redis modules (deploys, ~$4, very slow)
	@echo "Testing core infrastructure modules..."
	@echo "⚠️  This will deploy real infrastructure (takes 30-45 minutes total)"
	@echo "⚠️  Estimated cost: ~$4"
	@read -p "Continue? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		go test -v -timeout 60m ./modules -run "TestECSFargateServiceModule|TestPostgreSQLModule|TestRedisModule"; \
	fi

# CI/CD targets (no prompts)
# Note: AWS_PROFILE= clears the profile so CI uses AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY
ci-test-module: ## CI: Test module (no prompts)
	AWS_PROFILE= go test -v -timeout 10m ./terragrunt/units -run TestDjangoModuleMinimal

ci-test-unit: ## CI: Test unit deployment (no prompts)
	AWS_PROFILE= go test -v -timeout 30m ./terragrunt/units -run TestUnitDjangoFargateService

ci-test-integration: ## CI: Test integration (no prompts)
	AWS_PROFILE= go test -v -timeout 30m -run TestDjangoIntegrationFull

ci-test-modules-minimal: ## CI: Test all modules without deployment (no prompts)
	AWS_PROFILE= go test -v -timeout 10m ./modules -run "Minimal"

ci-test-ecs-module: ## CI: Test ECS module (no prompts)
	AWS_PROFILE= go test -v -timeout 30m ./modules -run TestECSFargateServiceModule

ci-test-postgresql-module: ## CI: Test PostgreSQL module (no prompts)
	AWS_PROFILE= go test -v -timeout 45m ./modules -run TestPostgreSQLModule

ci-test-redis-module: ## CI: Test Redis module (no prompts)
	AWS_PROFILE= go test -v -timeout 30m ./modules -run TestRedisModule

ci-test-core-modules: ## CI: Test core modules (no prompts)
	AWS_PROFILE= go test -v -timeout 60m ./modules -run "TestECSFargateServiceModule|TestPostgreSQLModule|TestRedisModule"

ci-test-all: ci-test-module ci-test-unit ci-test-integration ci-test-modules-minimal ## CI: Run all tests (no prompts)
