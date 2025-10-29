#!/bin/bash

# Production Django Backend Stack Deployment Script
# This script orchestrates the deployment of the Django backend to production
# using Terragrunt and AWS resources.

set -euo pipefail  # Exit on error, undefined variable, or pipe failure

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check command availability
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed or not in PATH"
        exit 1
    fi
}

# Function to validate AWS credentials
validate_aws_credentials() {
    print_status "Validating AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not valid. Please configure AWS CLI."
        exit 1
    fi

    local account_id
    local identity
    account_id=$(aws sts get-caller-identity --query Account --output text)
    identity=$(aws sts get-caller-identity --query Arn --output text)
    print_success "Using AWS identity: $identity"
    print_success "AWS Account ID: $account_id"
}

# Function to query AWS for subnet IDs
query_subnet_ids() {
    local vpc_id=$1
    local subnet_type=$2

    print_status "Querying $subnet_type subnet IDs for VPC $vpc_id..."

    local subnet_ids
    subnet_ids=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$vpc_id" \
                  "Name=tag:Type,Values=$subnet_type" \
        --query 'Subnets[*].SubnetId' \
        --output text 2>/dev/null | tr '\t' ',')

    if [ -z "$subnet_ids" ]; then
        # Fallback to Name tag if Type tag doesn't exist
        subnet_ids=$(aws ec2 describe-subnets \
            --filters "Name=vpc-id,Values=$vpc_id" \
                      "Name=tag:Name,Values=*$subnet_type*" \
            --query 'Subnets[*].SubnetId' \
            --output text 2>/dev/null | tr '\t' ',')
    fi

    if [ -z "$subnet_ids" ]; then
        print_warning "No $subnet_type subnets found for VPC $vpc_id"
        return 1
    fi

    echo "$subnet_ids"
}

# Function to retrieve secret from AWS Secrets Manager
get_secret_value() {
    local secret_id=$1
    local json_key=${2:-}

    print_status "Retrieving secret: $secret_id"

    local secret_value
    if [ -n "$json_key" ]; then
        secret_value=$(aws secretsmanager get-secret-value \
            --secret-id "$secret_id" \
            --query "SecretString" \
            --output text 2>/dev/null | jq -r ".$json_key")
    else
        secret_value=$(aws secretsmanager get-secret-value \
            --secret-id "$secret_id" \
            --query "SecretString" \
            --output text 2>/dev/null)
    fi

    if [ -z "$secret_value" ] || [ "$secret_value" = "null" ]; then
        print_error "Failed to retrieve secret: $secret_id"
        return 1
    fi

    echo "$secret_value"
}

# Function to verify Docker image exists in ECR
verify_ecr_image() {
    local repository_url=$1
    local tag=$2

    # Extract repository name from URL
    local repository_name
    repository_name=$(echo "$repository_url" | awk -F'/' '{print $NF}')

    print_status "Verifying Docker image exists: $repository_url:$tag"

    # Check if image exists
    if aws ecr describe-images \
        --repository-name "$repository_name" \
        --image-ids imageTag="$tag" \
        --output text &> /dev/null; then
        print_success "Image verified: $repository_url:$tag"
        return 0
    else
        print_error "Image not found in ECR: $repository_url:$tag"
        return 1
    fi
}

# Function to prompt for user confirmation
confirm_deployment() {
    echo ""
    print_warning "┌─────────────────────────────────────────────────────────┐"
    print_warning "│           PRODUCTION DEPLOYMENT CONFIRMATION            │"
    print_warning "├─────────────────────────────────────────────────────────┤"
    print_warning "│ You are about to deploy to: PRODUCTION                 │"
    print_warning "│ This will affect live services and users               │"
    print_warning "│                                                         │"
    print_warning "│ Please review the plan output above carefully          │"
    print_warning "└─────────────────────────────────────────────────────────┘"
    echo ""

    read -r -p "Type 'deploy-production' to confirm deployment: " confirmation

    if [ "$confirmation" != "deploy-production" ]; then
        print_error "Deployment cancelled by user"
        exit 0
    fi
}

# Main deployment script
main() {
    print_status "Starting Django Backend Production Deployment"
    echo "================================================"

    # Check required commands
    print_status "Checking required tools..."
    check_command aws
    check_command terragrunt
    check_command jq
    check_command docker

    # Set AWS Profile
    export AWS_PROFILE=lightwave-admin-new
    print_success "AWS_PROFILE set to: $AWS_PROFILE"

    # Validate AWS credentials
    validate_aws_credentials

    # Set static VPC ID
    export VPC_ID=vpc-02f48c62006cacfae
    print_success "VPC_ID set to: $VPC_ID"

    # Query subnet IDs
    print_status "Querying AWS for subnet IDs..."

    if ! PRIVATE_SUBNET_IDS=$(query_subnet_ids "$VPC_ID" "private"); then
        print_error "Failed to find private subnets"
        exit 1
    fi
    export PRIVATE_SUBNET_IDS
    print_success "Private subnet IDs: $PRIVATE_SUBNET_IDS"

    if ! PUBLIC_SUBNET_IDS=$(query_subnet_ids "$VPC_ID" "public"); then
        print_error "Failed to find public subnets"
        exit 1
    fi
    export PUBLIC_SUBNET_IDS
    print_success "Public subnet IDs: $PUBLIC_SUBNET_IDS"

    if ! DB_SUBNET_IDS=$(query_subnet_ids "$VPC_ID" "database"); then
        # Fallback to private subnets if no dedicated database subnets
        print_warning "No database subnets found, using private subnets"
        DB_SUBNET_IDS="$PRIVATE_SUBNET_IDS"
    fi
    export DB_SUBNET_IDS
    print_success "Database subnet IDs: $DB_SUBNET_IDS"

    # Set ECR repository URL and image tag
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=${AWS_REGION:-us-east-1}

    export ECR_REPOSITORY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/lightwave-backend"

    # Get latest image tag or use provided one
    if [ -z "${IMAGE_TAG:-}" ]; then
        print_status "No IMAGE_TAG provided, using 'latest'"
        export IMAGE_TAG="latest"
    else
        print_status "Using provided IMAGE_TAG: $IMAGE_TAG"
    fi

    print_success "ECR Repository URL: $ECR_REPOSITORY_URL"
    print_success "Image Tag: $IMAGE_TAG"

    # Verify Docker image exists
    if ! verify_ecr_image "$ECR_REPOSITORY_URL" "$IMAGE_TAG"; then
        print_error "Please build and push the Docker image before deploying"
        echo "Run: docker build -t $ECR_REPOSITORY_URL:$IMAGE_TAG ."
        echo "     docker push $ECR_REPOSITORY_URL:$IMAGE_TAG"
        exit 1
    fi

    # Retrieve secrets from AWS Secrets Manager
    print_status "Retrieving secrets from AWS Secrets Manager..."

    # Django Secret Key
    DJANGO_SECRET_KEY_ARN="arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:lightwave/django/secret-key"
    if ! aws secretsmanager describe-secret --secret-id "$DJANGO_SECRET_KEY_ARN" &> /dev/null; then
        print_warning "Django secret key not found, will be created by Terraform"
    else
        print_success "Django secret key ARN verified: $DJANGO_SECRET_KEY_ARN"
    fi
    export DJANGO_SECRET_KEY_ARN

    # Database credentials
    export DB_MASTER_USERNAME="postgres"

    DB_PASSWORD_SECRET="lightwave/rds/master-password"
    DB_MASTER_PASSWORD=$(get_secret_value "$DB_PASSWORD_SECRET" "password" 2>/dev/null || echo "")
    if [ -z "$DB_MASTER_PASSWORD" ]; then
        print_warning "Database password not found in Secrets Manager, generating new one"
        DB_MASTER_PASSWORD=$(openssl rand -base64 32)
        print_status "Generated new database password"
    else
        print_success "Database password retrieved from Secrets Manager"
    fi
    export DB_MASTER_PASSWORD

    # Cloudflare credentials
    CLOUDFLARE_SECRET="lightwave/cloudflare/api-credentials"
    CLOUDFLARE_API_TOKEN=$(get_secret_value "$CLOUDFLARE_SECRET" "api_token" 2>/dev/null || echo "")
    CLOUDFLARE_ZONE_ID=$(get_secret_value "$CLOUDFLARE_SECRET" "zone_id" 2>/dev/null || echo "")
    export CLOUDFLARE_API_TOKEN
    export CLOUDFLARE_ZONE_ID

    if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ZONE_ID" ]; then
        print_warning "Cloudflare credentials not found in Secrets Manager"
        print_warning "DNS configuration will be skipped unless credentials are provided"

        # Allow optional manual input
        read -r -p "Enter Cloudflare API Token (or press Enter to skip): " cf_token
        read -r -p "Enter Cloudflare Zone ID (or press Enter to skip): " cf_zone

        [ -n "$cf_token" ] && export CLOUDFLARE_API_TOKEN="$cf_token"
        [ -n "$cf_zone" ] && export CLOUDFLARE_ZONE_ID="$cf_zone"
    else
        print_success "Cloudflare credentials retrieved from Secrets Manager"
    fi

    # Set Django allowed hosts
    export DJANGO_ALLOWED_HOSTS="api.lightwave.media,*.lightwave.media,localhost,127.0.0.1"
    print_success "Django allowed hosts set: $DJANGO_ALLOWED_HOSTS"

    # Display configuration summary
    echo ""
    print_status "Configuration Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "AWS Profile:          $AWS_PROFILE"
    echo "AWS Region:           $AWS_REGION"
    echo "VPC ID:               $VPC_ID"
    echo "Private Subnets:      $PRIVATE_SUBNET_IDS"
    echo "Public Subnets:       $PUBLIC_SUBNET_IDS"
    echo "Database Subnets:     $DB_SUBNET_IDS"
    echo "ECR Repository:       $ECR_REPOSITORY_URL"
    echo "Image Tag:            $IMAGE_TAG"
    echo "Django Allowed Hosts: $DJANGO_ALLOWED_HOSTS"
    echo "DB Master Username:   $DB_MASTER_USERNAME"
    echo "Cloudflare Configured: $([ -n "$CLOUDFLARE_API_TOKEN" ] && echo "Yes" || echo "No")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Change to stack directory
    STACK_DIR="$(dirname "$0")"
    cd "$STACK_DIR"
    print_status "Working directory: $(pwd)"

    # Run Terragrunt stack plan
    print_status "Running Terragrunt stack plan..."
    echo ""

    if ! terragrunt stack plan; then
        print_error "Terragrunt plan failed"
        exit 1
    fi

    echo ""
    print_success "Terragrunt plan completed successfully"

    # Prompt for confirmation
    confirm_deployment

    # Run Terragrunt stack apply
    print_status "Running Terragrunt stack apply..."
    echo ""

    if ! terragrunt stack apply --auto-approve; then
        print_error "Terragrunt apply failed"
        exit 1
    fi

    echo ""
    print_success "═══════════════════════════════════════════════════════════"
    print_success "  Django Backend Production Deployment Completed!"
    print_success "═══════════════════════════════════════════════════════════"
    echo ""

    # Display post-deployment information
    print_status "Post-deployment steps:"
    echo "1. Verify ECS service is running: aws ecs describe-services --cluster lightwave-prod --services lightwave-django"
    echo "2. Check application logs: aws logs tail /ecs/lightwave-django --follow"
    echo "3. Test API endpoint: curl https://api.lightwave.media/health/"
    echo "4. Monitor CloudWatch metrics for any issues"
    echo ""

    print_success "Deployment completed at: $(date)"
}

# Handle script interruption
trap 'print_error "Deployment interrupted by user"; exit 130' INT TERM

# Run main function
main "$@"