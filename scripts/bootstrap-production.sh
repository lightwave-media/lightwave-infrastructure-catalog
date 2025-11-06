#!/bin/bash
set -e

# =============================================================================
# Bootstrap Django Backend Production Infrastructure
# =============================================================================
#
# This script automates the complete deployment of production infrastructure:
# 1. Verifies prerequisites (AWS credentials, Cloudflare token, etc.)
# 2. Builds and pushes Docker image to ECR
# 3. Deploys infrastructure via Terragrunt stack
# 4. Waits for health checks to pass
# 5. Outputs production URLs and connection details
#
# Usage:
#   ./scripts/bootstrap-production.sh
#
# Prerequisites:
#   - AWS CLI configured with lightwave-admin-new profile
#   - Docker installed and running
#   - Terragrunt installed
#   - Environment variables set (see Prerequisites section)
#
# =============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions for colored output
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DJANGO_SRC_DIR="$REPO_ROOT/units/django-fargate-stateful-service/src"
STACK_DIR="$REPO_ROOT/stacks/django-backend-prod"

echo ""
echo "=========================================="
echo "  Django Backend Production Bootstrap"
echo "=========================================="
echo ""

# =============================================================================
# Step 1: Verify Prerequisites
# =============================================================================

info "Step 1/6: Verifying prerequisites..."

# Check AWS credentials
if ! aws sts get-caller-identity --profile lightwave-admin-new > /dev/null 2>&1; then
  error "AWS credentials not configured for profile lightwave-admin-new"
fi
success "AWS credentials verified"

# Check required tools
for tool in docker terragrunt aws; do
  if ! command -v $tool &> /dev/null; then
    error "$tool is not installed"
  fi
done
success "Required tools installed: docker, terragrunt, aws"

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
  error "Docker is not running. Please start Docker Desktop."
fi
success "Docker is running"

# Check required environment variables
REQUIRED_VARS=(
  "VPC_ID"
  "PRIVATE_SUBNET_IDS"
  "PUBLIC_SUBNET_IDS"
  "ECR_REPOSITORY_URL"
  "DJANGO_SECRET_KEY_ARN"
  "CLOUDFLARE_API_TOKEN"
  "CLOUDFLARE_ZONE_ID"
  "DB_MASTER_PASSWORD"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    MISSING_VARS+=("$var")
  fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
  error "Missing required environment variables: ${MISSING_VARS[*]}"
fi
success "All required environment variables set"

# Set optional defaults
export IMAGE_TAG="${IMAGE_TAG:-prod}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export DB_MASTER_USERNAME="${DB_MASTER_USERNAME:-postgres}"
export DJANGO_ALLOWED_HOSTS="${DJANGO_ALLOWED_HOSTS:-api.lightwave-media.ltd,*.amazonaws.com}"

echo ""

# =============================================================================
# Step 2: Build Docker Image
# =============================================================================

info "Step 2/6: Building Docker image..."

cd "$DJANGO_SRC_DIR"

# Build for ARM64 (Fargate graviton)
info "Building for linux/arm64 platform..."
docker build --platform linux/arm64 -t lightwave-django:$IMAGE_TAG .

success "Docker image built: lightwave-django:$IMAGE_TAG"
echo ""

# =============================================================================
# Step 3: Push to ECR
# =============================================================================

info "Step 3/6: Pushing image to ECR..."

# Login to ECR
aws ecr get-login-password --region $AWS_REGION --profile lightwave-admin-new \
  | docker login --username AWS --password-stdin $ECR_REPOSITORY_URL

# Tag and push
docker tag lightwave-django:$IMAGE_TAG $ECR_REPOSITORY_URL:$IMAGE_TAG
docker push $ECR_REPOSITORY_URL:$IMAGE_TAG

success "Image pushed to ECR: $ECR_REPOSITORY_URL:$IMAGE_TAG"
echo ""

# =============================================================================
# Step 4: Deploy Infrastructure
# =============================================================================

info "Step 4/6: Deploying infrastructure via Terragrunt stack..."

cd "$STACK_DIR"

# Run Terragrunt stack plan first
info "Running Terragrunt plan..."
terragrunt stack plan

# Prompt for confirmation
echo ""
read -p "Proceed with deployment? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  warning "Deployment cancelled by user"
  exit 0
fi

# Deploy stack
info "Deploying stack (this may take 5-10 minutes)..."
terragrunt stack apply

success "Infrastructure deployed successfully"
echo ""

# =============================================================================
# Step 5: Wait for Health Checks
# =============================================================================

info "Step 5/6: Waiting for Django service to become healthy..."

# Get ALB DNS name from Terraform output
ALB_DNS=$(cd "$REPO_ROOT/units/django-fargate-stateful-service" && terragrunt output -raw alb_dns_name 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ]; then
  warning "Could not retrieve ALB DNS name from Terraform output"
  warning "Skipping health check. Please verify manually."
else
  HEALTH_URL="http://$ALB_DNS/health/live/"
  MAX_RETRIES=36  # 3 minutes with 5-second intervals
  RETRY_DELAY=5

  info "Health check URL: $HEALTH_URL"
  info "Waiting for service to be ready (max 3 minutes)..."

  for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
      success "Service is healthy after $((i * RETRY_DELAY)) seconds"
      break
    fi

    if [ $i -eq $MAX_RETRIES ]; then
      warning "Service did not become healthy within timeout"
      warning "Check CloudWatch logs: aws logs tail /ecs/lightwave-django-prod --follow"
    else
      echo -n "."
      sleep $RETRY_DELAY
    fi
  done
  echo ""
fi

echo ""

# =============================================================================
# Step 6: Output Production URLs
# =============================================================================

info "Step 6/6: Deployment complete!"
echo ""
echo "=========================================="
echo "  Production Infrastructure Details"
echo "=========================================="
echo ""

# Get Cloudflare URL
CLOUDFLARE_URL=$(cd "$REPO_ROOT/units/cloudflare-dns" && terragrunt output -raw url 2>/dev/null || echo "https://api.lightwave-media.ltd")

echo "Production API URL:"
echo "  $CLOUDFLARE_URL"
echo ""

echo "Health Endpoints:"
echo "  Liveness:  $CLOUDFLARE_URL/health/live/"
echo "  Readiness: $CLOUDFLARE_URL/health/ready/"
echo ""

echo "Admin Interface:"
echo "  $CLOUDFLARE_URL/admin/"
echo ""

echo "Database Connection:"
DB_ENDPOINT=$(cd "$REPO_ROOT/units/postgresql" && terragrunt output -raw endpoint 2>/dev/null || echo "Not available")
echo "  Endpoint: $DB_ENDPOINT"
echo ""

echo "Redis Connection:"
REDIS_ENDPOINT=$(cd "$REPO_ROOT/units/redis" && terragrunt output -raw primary_endpoint_address 2>/dev/null || echo "Not available")
echo "  Endpoint: $REDIS_ENDPOINT:6379"
echo ""

echo "Monitoring:"
echo "  CloudWatch Logs:  aws logs tail /ecs/lightwave-django-prod --follow"
echo "  Cloudflare Dashboard: https://dash.cloudflare.com"
echo "  AWS Console: https://console.aws.amazon.com/ecs/v2/clusters/lightwave-django-prod"
echo ""

echo "=========================================="
echo ""

success "Production deployment complete!"
echo ""

# =============================================================================
# Post-Deployment Instructions
# =============================================================================

info "Next Steps:"
echo ""
echo "1. Run database migrations:"
echo "   cd $REPO_ROOT/units/django-fargate-stateful-service"
echo "   terragrunt run-migrations"
echo ""
echo "2. Create Django superuser:"
echo "   terragrunt create-superuser"
echo ""
echo "3. Test endpoints:"
echo "   curl $CLOUDFLARE_URL/health/live/"
echo "   curl $CLOUDFLARE_URL/health/ready/"
echo ""
echo "4. Access Django admin:"
echo "   open $CLOUDFLARE_URL/admin/"
echo ""

exit 0
