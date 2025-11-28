"""
Deploy Runner Invoker Lambda

This Lambda function triggers ECS tasks for the deploy runner.
It validates requests and starts the appropriate ECS Fargate task.
"""

import json
import logging
import os
import boto3
from typing import Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients
ecs_client = boto3.client("ecs")

# Environment variables (set by Terraform)
CLUSTER_ARN = os.environ.get("CLUSTER_ARN", "")
SUBNET_IDS = os.environ.get("SUBNET_IDS", "").split(",")
SECURITY_GROUP_IDS = os.environ.get("SECURITY_GROUP_IDS", "").split(",")

# Task definition mapping
TASK_DEFINITIONS = {
    "docker_builder": os.environ.get("DOCKER_BUILDER_TASK_ARN", ""),
    "terraform_runner": os.environ.get("TERRAFORM_RUNNER_TASK_ARN", ""),
    "app_deployer": os.environ.get("APP_DEPLOYER_TASK_ARN", ""),
}

# Allowed apps (security: only deploy known apps)
ALLOWED_APPS = os.environ.get("ALLOWED_APPS", "cineos,photographos,createos,lightwave-backend").split(",")

# Allowed operations
ALLOWED_OPERATIONS = ["build", "deploy", "plan", "apply"]


def validate_request(event: dict) -> tuple[bool, str]:
    """Validate the incoming request."""

    # Required fields
    required_fields = ["task_type"]
    for field in required_fields:
        if field not in event:
            return False, f"Missing required field: {field}"

    # Validate task type
    task_type = event.get("task_type")
    if task_type not in TASK_DEFINITIONS:
        return False, f"Invalid task_type: {task_type}. Must be one of: {list(TASK_DEFINITIONS.keys())}"

    # Validate app name if provided
    app_name = event.get("app_name")
    if app_name and app_name not in ALLOWED_APPS:
        return False, f"App not allowed: {app_name}. Allowed apps: {ALLOWED_APPS}"

    # Validate operation if provided
    operation = event.get("operation")
    if operation and operation not in ALLOWED_OPERATIONS:
        return False, f"Operation not allowed: {operation}. Allowed: {ALLOWED_OPERATIONS}"

    return True, ""


def build_container_overrides(event: dict) -> list[dict]:
    """Build container overrides based on the request."""

    task_type = event.get("task_type")
    overrides = []

    if task_type == "docker_builder":
        # Kaniko command for building Docker images
        app_name = event.get("app_name", "")
        git_ref = event.get("git_ref", "main")
        ecr_repo = event.get("ecr_repository", "")
        dockerfile = event.get("dockerfile", "Dockerfile")

        # Kaniko executor command
        command = [
            "--context", f"git://github.com/lightwave-media/{app_name}.git#{git_ref}",
            "--dockerfile", dockerfile,
            "--destination", f"{ecr_repo}:{git_ref}",
            "--destination", f"{ecr_repo}:latest",
            "--cache=true",
        ]

        overrides.append({
            "name": "kaniko",
            "command": command,
        })

    elif task_type == "terraform_runner":
        # Terraform/Terragrunt command
        operation = event.get("operation", "plan")
        working_dir = event.get("working_dir", ".")

        command = f"cd {working_dir} && terragrunt {operation} --terragrunt-non-interactive"

        overrides.append({
            "name": "terraform",
            "command": [command],
        })

    elif task_type == "app_deployer":
        # Combined build + deploy
        app_name = event.get("app_name", "")
        git_ref = event.get("git_ref", "main")
        environment = event.get("environment", "prod")
        ecr_repo = event.get("ecr_repository", "")
        ecs_cluster = event.get("ecs_cluster", "")
        ecs_service = event.get("ecs_service", "")

        # Build environment variables
        env_vars = [
            {"name": "APP_NAME", "value": app_name},
            {"name": "GIT_REF", "value": git_ref},
            {"name": "ENVIRONMENT", "value": environment},
            {"name": "ECR_REPOSITORY", "value": ecr_repo},
            {"name": "ECS_CLUSTER", "value": ecs_cluster},
            {"name": "ECS_SERVICE", "value": ecs_service},
        ]

        overrides.append({
            "name": "deployer",
            "environment": env_vars,
        })

    return overrides


def start_ecs_task(event: dict) -> dict:
    """Start an ECS Fargate task."""

    task_type = event.get("task_type")
    task_definition_arn = TASK_DEFINITIONS.get(task_type)

    container_overrides = build_container_overrides(event)

    logger.info(f"Starting ECS task: {task_type}")
    logger.info(f"Task definition: {task_definition_arn}")
    logger.info(f"Container overrides: {json.dumps(container_overrides)}")

    response = ecs_client.run_task(
        cluster=CLUSTER_ARN,
        taskDefinition=task_definition_arn,
        launchType="FARGATE",
        networkConfiguration={
            "awsvpcConfiguration": {
                "subnets": SUBNET_IDS,
                "securityGroups": SECURITY_GROUP_IDS,
                "assignPublicIp": "DISABLED",
            }
        },
        overrides={
            "containerOverrides": container_overrides,
        },
        # Add metadata for tracking
        tags=[
            {"key": "TaskType", "value": task_type},
            {"key": "AppName", "value": event.get("app_name", "n/a")},
            {"key": "GitRef", "value": event.get("git_ref", "n/a")},
            {"key": "TriggeredBy", "value": event.get("triggered_by", "lambda")},
        ],
    )

    # Extract task info
    tasks = response.get("tasks", [])
    if not tasks:
        failures = response.get("failures", [])
        raise Exception(f"Failed to start ECS task: {failures}")

    task = tasks[0]
    task_arn = task.get("taskArn", "")
    task_id = task_arn.split("/")[-1] if task_arn else ""

    return {
        "task_arn": task_arn,
        "task_id": task_id,
        "cluster_arn": CLUSTER_ARN,
        "status": task.get("lastStatus", "PENDING"),
    }


def handler(event: dict, context: Any) -> dict:
    """Lambda handler function."""

    logger.info(f"Received event: {json.dumps(event)}")

    try:
        # Validate request
        is_valid, error_message = validate_request(event)
        if not is_valid:
            logger.error(f"Validation failed: {error_message}")
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "success": False,
                    "error": error_message,
                }),
            }

        # Start ECS task
        result = start_ecs_task(event)

        logger.info(f"Task started successfully: {result}")

        return {
            "statusCode": 200,
            "body": json.dumps({
                "success": True,
                "task_arn": result["task_arn"],
                "task_id": result["task_id"],
                "cluster_arn": result["cluster_arn"],
                "status": result["status"],
                "message": f"ECS task started: {result['task_id']}",
            }),
        }

    except Exception as e:
        logger.exception(f"Error starting task: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "success": False,
                "error": str(e),
            }),
        }
