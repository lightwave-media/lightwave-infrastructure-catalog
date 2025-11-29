#!/bin/bash
# =============================================================================
# LightWave App Deployer Script
# =============================================================================
#
# This script builds a Docker image and deploys it to ECS.
# Environment variables:
#   APP_NAME        - Application name (e.g., cineos)
#   GIT_REF         - Git commit SHA or tag
#   ENVIRONMENT     - Target environment (prod, staging, dev)
#   ECR_REPOSITORY  - Full ECR repository URL
#   ECS_CLUSTER     - ECS cluster name
#   ECS_SERVICE     - ECS service name
# =============================================================================

set -euo pipefail

echo "========================================"
echo "LightWave App Deployer"
echo "========================================"
echo ""
echo "App:         ${APP_NAME:-not set}"
echo "Git Ref:     ${GIT_REF:-not set}"
echo "Environment: ${ENVIRONMENT:-not set}"
echo "ECR Repo:    ${ECR_REPOSITORY:-not set}"
echo "ECS Cluster: ${ECS_CLUSTER:-not set}"
echo "ECS Service: ${ECS_SERVICE:-not set}"
echo ""

# Validate required variables
for var in APP_NAME GIT_REF ECR_REPOSITORY ECS_CLUSTER ECS_SERVICE; do
    if [ -z "${!var:-}" ]; then
        echo "❌ Error: $var is required but not set"
        exit 1
    fi
done

# Extract short SHA for tagging
SHORT_SHA="${GIT_REF:0:7}"

echo "========================================"
echo "Step 1: Build Docker Image"
echo "========================================"

# Get ECR login
echo "Authenticating with ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
    /kaniko/executor --version > /dev/null 2>&1 || true

# Determine Dockerfile to use
DOCKERFILE="Dockerfile"
if [ -f "Dockerfile.web" ]; then
    DOCKERFILE="Dockerfile.web"
fi

echo "Using Dockerfile: $DOCKERFILE"
echo "Building image for ${APP_NAME}:${SHORT_SHA}..."

# Build with Kaniko
/kaniko/executor \
    --context "git://github.com/lightwave-media/${APP_NAME}.git#refs/heads/main" \
    --dockerfile "${DOCKERFILE}" \
    --destination "${ECR_REPOSITORY}:${SHORT_SHA}" \
    --destination "${ECR_REPOSITORY}:latest" \
    --cache=true \
    --cache-repo="${ECR_REPOSITORY}/cache" \
    --snapshotMode=redo \
    --compressed-caching=false

echo "✅ Docker image built and pushed"
echo ""

echo "========================================"
echo "Step 2: Update ECS Service"
echo "========================================"

# Get current task definition
echo "Getting current task definition..."
TASK_DEF_ARN=$(aws ecs describe-services \
    --cluster "${ECS_CLUSTER}" \
    --services "${ECS_SERVICE}" \
    --query 'services[0].taskDefinition' \
    --output text)

echo "Current task definition: ${TASK_DEF_ARN}"

# Get task definition details
TASK_DEF=$(aws ecs describe-task-definition \
    --task-definition "${TASK_DEF_ARN}" \
    --query 'taskDefinition')

# Update image in task definition
echo "Updating image to ${ECR_REPOSITORY}:${SHORT_SHA}..."
NEW_TASK_DEF=$(echo "${TASK_DEF}" | jq \
    --arg IMAGE "${ECR_REPOSITORY}:${SHORT_SHA}" \
    '.containerDefinitions[0].image = $IMAGE |
     del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')

# Register new task definition
echo "Registering new task definition..."
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json "${NEW_TASK_DEF}" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "New task definition: ${NEW_TASK_DEF_ARN}"

# Update service
echo "Updating ECS service..."
aws ecs update-service \
    --cluster "${ECS_CLUSTER}" \
    --service "${ECS_SERVICE}" \
    --task-definition "${NEW_TASK_DEF_ARN}" \
    --force-new-deployment \
    > /dev/null

echo ""
echo "========================================"
echo "Step 3: Wait for Service Stability"
echo "========================================"

echo "Waiting for service to stabilize..."
aws ecs wait services-stable \
    --cluster "${ECS_CLUSTER}" \
    --services "${ECS_SERVICE}"

echo ""
echo "========================================"
echo "✅ Deployment Complete!"
echo "========================================"
echo ""
echo "App:     ${APP_NAME}"
echo "Image:   ${ECR_REPOSITORY}:${SHORT_SHA}"
echo "Service: ${ECS_SERVICE}"
echo "Cluster: ${ECS_CLUSTER}"
echo ""
