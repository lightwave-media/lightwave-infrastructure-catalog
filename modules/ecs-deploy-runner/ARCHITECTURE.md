# LightWave CI/CD Pipeline Architecture

## Overview

This document describes the ECS Deploy Runner architecture for LightWave Media's infrastructure.
Based on [Gruntwork Pipelines](https://gruntwork.io/pipelines/) patterns, adapted for our needs.

## Problem Statement

**Current State (Anti-Pattern):**
- Each app repo (cineos, photographos, etc.) has its own GitHub Actions workflow
- CI server directly runs `docker build`, `docker push`, `aws ecs update-service`
- AWS credentials stored in CI server (security risk)
- No centralized deployment management
- Inconsistent deployment patterns across apps

**Desired State:**
- Centralized pipeline in `infrastructure-live` repo
- CI server only triggers deployments (no AWS credentials)
- Deployments run in isolated ECS tasks in our AWS account
- Consistent, auditable deployment process for all apps

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           APPLICATION REPOS                                  │
│         (cineos, photographos, createos, lightwave-backend)                 │
│                                                                             │
│   On push to main:                                                          │
│   1. Run tests (in app repo)                                                │
│   2. Trigger workflow in infrastructure-live (via repository_dispatch)      │
└────────────────────────────────────┬────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        INFRASTRUCTURE-LIVE REPO                              │
│                    (.github/workflows/deploy-app.yml)                        │
│                                                                             │
│   Receives dispatch with:                                                   │
│   - app_name: "cineos"                                                      │
│   - git_ref: "abc123"                                                       │
│   - environment: "prod"                                                     │
│                                                                             │
│   Actions:                                                                  │
│   1. Authenticate via GitHub OIDC → AWS (limited permissions)               │
│   2. Invoke ECS Deploy Runner Lambda                                        │
│   3. Stream logs from ECS task                                              │
│   4. Report status back                                                     │
└────────────────────────────────────┬────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INVOKER LAMBDA                                       │
│                   (lightwave-deploy-runner-invoker)                          │
│                                                                             │
│   1. Validates request against allowlist                                    │
│   2. Determines which ECS task definition to use                            │
│   3. Starts ECS Fargate task with parameters                                │
│   4. Returns task ARN for log streaming                                     │
└────────────────────────────────────┬────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ECS DEPLOY RUNNER                                     │
│                   (Fargate tasks in private subnet)                          │
│                                                                             │
│   Task Definitions:                                                         │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ docker-builder                                                       │   │
│   │ - Uses Kaniko to build Docker images                                │   │
│   │ - Clones app repo, builds Dockerfile                                │   │
│   │ - Pushes to ECR                                                     │   │
│   │ - IAM: ecr:*, logs:*                                                │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ terraform-runner                                                     │   │
│   │ - Runs terragrunt plan/apply                                        │   │
│   │ - Updates ECS service with new image                                │   │
│   │ - IAM: Full deployment permissions                                  │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ app-deployer                                                         │   │
│   │ - Combined: build + deploy in sequence                              │   │
│   │ - Single task for simple app deployments                            │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. ECS Deploy Runner Module (`modules/ecs-deploy-runner`)

Creates:
- ECS Cluster (Fargate)
- Task Definitions for each runner type
- IAM roles (task execution + task role)
- CloudWatch Log Groups
- Security Groups

### 2. Invoker Lambda Module (`modules/deploy-runner-invoker`)

Creates:
- Lambda function (Python)
- IAM role for Lambda
- API Gateway or direct invocation endpoint

### 3. GitHub OIDC Module (`modules/github-oidc-role`)

Creates:
- IAM OIDC Provider for GitHub Actions
- IAM Role with trust policy for specific repos
- Minimal permissions (invoke Lambda only)

### 4. App Deployment Workflow (in infrastructure-live)

GitHub Actions workflow that:
- Receives repository_dispatch from app repos
- Invokes Lambda with deployment parameters
- Streams ECS task logs
- Reports success/failure

## Deployment Flow

### For App Code Changes (e.g., cineos)

```
1. Developer pushes to cineos main branch
2. cineos/.github/workflows/trigger-deploy.yml runs:
   - Runs tests
   - On success: sends repository_dispatch to infrastructure-live
3. infrastructure-live/.github/workflows/deploy-app.yml runs:
   - Receives: {app: "cineos", ref: "abc123", env: "prod"}
   - Authenticates via OIDC (no stored credentials)
   - Invokes Lambda: deploy-runner-invoker
4. Lambda validates and starts ECS task:
   - Task: app-deployer
   - Params: {app: "cineos", ref: "abc123", env: "prod"}
5. ECS Task runs:
   a. Clone cineos repo at ref abc123
   b. Build Docker image with Kaniko
   c. Push to ECR: cineos:abc123 + cineos:latest
   d. Update ECS service to use new image
   e. Wait for service stability
6. Logs stream back to GitHub Actions
7. Success/failure reported
```

### For Infrastructure Changes

```
1. Developer pushes to infrastructure-live main branch
2. infrastructure-live/.github/workflows/deploy-infra.yml runs:
   - Detects changed Terragrunt units
   - Invokes Lambda for each: terraform-runner
3. ECS Task runs terragrunt plan/apply
4. Results reported in PR/commit
```

## Security Model

### Principle of Least Privilege

| Component | Permissions |
|-----------|-------------|
| GitHub Actions (app repos) | None (just triggers dispatch) |
| GitHub Actions (infra-live) | Lambda invoke only (via OIDC) |
| Invoker Lambda | ECS RunTask, PassRole, Logs |
| Docker Builder Task | ECR push, Logs, clone repos |
| Terraform Runner Task | Full AWS deployment perms |
| App Deployer Task | ECR push, ECS update, Logs |

### Credential Flow

```
GitHub Actions → OIDC Token → AWS STS → Temporary credentials (15min)
                                              │
                                              ▼
                                    Lambda invoke only
                                              │
                                              ▼
                                    ECS Task assumes own role
                                    (broader permissions, isolated)
```

## Directory Structure

```
Infrastructure/
├── lightwave-infrastructure-catalog/
│   └── modules/
│       ├── ecs-deploy-runner/          # NEW: ECS cluster + tasks
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   ├── iam.tf
│       │   └── task-definitions/
│       │       ├── docker-builder.json
│       │       ├── terraform-runner.json
│       │       └── app-deployer.json
│       │
│       ├── deploy-runner-invoker/      # NEW: Lambda invoker
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── lambda/
│       │       └── invoker.py
│       │
│       └── github-oidc-role/           # NEW: OIDC for GitHub
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
└── lightwave-infrastructure-live/
    ├── _global/                         # NEW: Account-wide resources
    │   └── us-east-1/
    │       └── deploy-runner/
    │           └── terragrunt.hcl       # Deploys ECS Deploy Runner
    │
    ├── .github/
    │   └── workflows/
    │       ├── deploy-nonprod.yml       # Existing
    │       ├── deploy-prod.yml          # Existing
    │       ├── deploy-app.yml           # NEW: App deployment handler
    │       └── build-image.yml          # NEW: Image build handler
    │
    └── prod/
        └── us-east-1/
            └── cineos/                  # Existing
```

## Implementation Phases

### Phase 1: Foundation (This PR)
- [ ] Create `ecs-deploy-runner` module
- [ ] Create `deploy-runner-invoker` module
- [ ] Create `github-oidc-role` module
- [ ] Deploy to infrastructure-live/_global

### Phase 2: App Deployment
- [ ] Create `deploy-app.yml` workflow
- [ ] Create `trigger-deploy.yml` for app repos
- [ ] Test with cineos deployment
- [ ] Remove old one-off workflows

### Phase 3: Infrastructure Deployment
- [ ] Migrate infrastructure workflows to use deploy runner
- [ ] Add drift detection scheduled runs
- [ ] Add PR plan previews

## Environment Variables / Secrets

### Stored in AWS Secrets Manager (accessed by ECS tasks)
- `/lightwave/cicd/github-app-private-key` - For cloning private repos
- `/lightwave/cicd/docker-hub-token` - If using Docker Hub base images

### Passed to ECS Task at Runtime
- `APP_NAME` - Application to deploy
- `GIT_REF` - Commit SHA or tag
- `ENVIRONMENT` - prod/staging/dev
- `ECR_REPOSITORY` - Target ECR repo URL
- `ECS_CLUSTER` - Target ECS cluster
- `ECS_SERVICE` - Target ECS service

## Cost Considerations

- ECS Fargate: Pay per task execution (~$0.01 per deployment)
- Lambda: Negligible (invocation only)
- CloudWatch Logs: ~$0.50/GB ingested
- Estimated monthly cost for 100 deployments: < $5

## Alternatives Considered

1. **GitHub Actions direct deployment** (current)
   - Pros: Simple, no additional infrastructure
   - Cons: Credentials in CI, no isolation, inconsistent

2. **AWS CodePipeline/CodeBuild**
   - Pros: Native AWS, integrated
   - Cons: Vendor lock-in, complex, expensive at scale

3. **ECS Deploy Runner (chosen)**
   - Pros: Secure, isolated, consistent, Gruntwork pattern
   - Cons: More setup, custom implementation

## References

- [Gruntwork ECS Deploy Runner](https://docs.gruntwork.io/reference/services/ci-cd-pipeline/ecs-deploy-runner/)
- [Gruntwork Pipelines](https://gruntwork.io/pipelines/)
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Kaniko Docker Builder](https://github.com/GoogleContainerTools/kaniko)
