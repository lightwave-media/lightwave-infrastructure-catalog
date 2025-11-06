# Secret Management Examples

This directory contains example configurations for managing secrets using AWS Secrets Manager with Terragrunt Stacks.

## Directory Structure

```
secret-management/
├── README.md                           # This file
├── 01-basic-secret/                    # Simple secret creation
├── 02-auto-generated-password/         # Auto-generated passwords
├── 03-secret-with-rotation/            # Automatic rotation setup
├── 04-backend-service-stack/           # Complete backend service with secrets
└── 05-multi-environment/               # Multi-environment secret management
```

## Examples Overview

### 1. Basic Secret Creation

Simple example creating a secret with a provided value.

**Use case:** API keys, service tokens, manually managed credentials

### 2. Auto-Generated Password

Automatically generate secure random passwords for secrets.

**Use case:** Database passwords, JWT secrets, encryption keys

### 3. Secret with Automatic Rotation

Configure automatic secret rotation with Lambda integration.

**Use case:** Production database passwords requiring regular rotation

### 4. Backend Service Stack

Complete stack showing how to create secrets and reference them in other resources (like RDS, ECS).

**Use case:** Full service deployment with proper secret management

### 5. Multi-Environment Secret Management

Managing secrets across dev, staging, and production environments.

**Use case:** Consistent secret structure across all environments

## Quick Start

1. Navigate to an example directory:
   ```bash
   cd 01-basic-secret/
   ```

2. Review the configuration:
   ```bash
   cat terragrunt.hcl
   ```

3. Plan the changes:
   ```bash
   terragrunt plan
   ```

4. Apply if satisfied:
   ```bash
   terragrunt apply
   ```

## Best Practices Demonstrated

- Proper secret naming conventions following `/environment/service/secret_type` pattern
- Use of auto-generated passwords for enhanced security
- Separation of secret creation from resource usage (dependency pattern)
- Tagging strategy for secret organization
- Rotation configuration for production secrets
- Environment-specific configurations

## Related Documentation

- [Secret Management Module](../../units/secret/README.md)
- [SOP: Secrets Management](/.agent/sops/SOP_SECRETS_MANAGEMENT.md)
- [Helper Scripts](../../../lightwave-infrastructure-live/scripts/)
