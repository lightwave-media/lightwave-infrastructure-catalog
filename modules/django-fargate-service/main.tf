# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS FARGATE CLUSTER FOR DJANGO
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_cluster" "fargate" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE CLOUDWATCH LOG GROUP FOR DJANGO LOGS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "django" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = var.name
    Environment = var.environment
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_service" "service" {
  name            = var.name
  cluster         = aws_ecs_cluster.fargate.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.service.arn

  load_balancer {
    container_name   = var.name
    container_port   = var.container_port
    target_group_arn = aws_lb_target_group.ecs.arn
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [local.service_sg_id]
    assign_public_ip = false
  }

  # Enable circuit breaker for safe deployments
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Ensure ALB is provisioned first
  depends_on = [aws_lb.ecs, aws_lb_listener.http, aws_lb_listener_rule.forward_all, aws_lb_target_group.ecs]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS TASK DEFINITION WITH DJANGO CONTAINER
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Construct Django environment variables
  django_env_vars = merge(
    {
      DJANGO_SETTINGS_MODULE = var.django_settings_module
      DJANGO_ALLOWED_HOSTS   = var.django_allowed_hosts
      DATABASE_URL           = var.database_url
      DEBUG                  = tostring(var.debug)
      ENVIRONMENT            = var.environment
      AWS_REGION             = var.aws_region
      AWS_DEFAULT_REGION     = var.aws_region
    },
    var.redis_url != null ? {
      REDIS_URL         = var.redis_url
      CELERY_BROKER_URL = coalesce(var.celery_broker_url, var.redis_url)
    } : {},
    var.additional_environment_variables
  )

  # Convert environment variables to ECS format
  environment_vars = [
    for key, value in local.django_env_vars : {
      name  = key
      value = value
    }
  ]

  # Secrets from AWS Secrets Manager
  secrets = [
    {
      name      = "DJANGO_SECRET_KEY"
      valueFrom = var.django_secret_key_arn
    }
  ]

  # Container definitions for Django
  container_definitions = jsonencode([
    {
      name      = var.name
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      cpu       = var.cpu
      memory    = var.memory
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = local.environment_vars
      secrets     = local.secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.django.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

resource "aws_ecs_task_definition" "service" {
  family                   = var.name
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  container_definitions    = local.container_definitions
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = local.task_role_arn

  runtime_platform {
    cpu_architecture        = var.cpu_architecture
    operating_system_family = "LINUX"
  }

  tags = {
    Name        = var.name
    Environment = var.environment
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM ROLE FOR ECS TASK EXECUTION
# This role is used by ECS to pull images, write logs, and access secrets
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.name}-execution-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add permission to read secrets from Secrets Manager
resource "aws_iam_role_policy" "secrets_access" {
  name = "${var.name}-secrets-access"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.django_secret_key_arn
        ]
      }
    ]
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM ROLE FOR ECS TASK (APPLICATION-LEVEL AWS ACCESS)
# This role is used by the Django application to access AWS services
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_role" {
  count = var.task_role_arn == null ? 1 : 0
  name  = "${var.name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.name}-task-role"
    Environment = var.environment
  }
}

# Basic policy for Django to write logs and access S3 (for media files)
resource "aws_iam_role_policy" "task_basic_permissions" {
  count = var.task_role_arn == null ? 1 : 0
  name  = "${var.name}-task-basic-permissions"
  role  = aws_iam_role.ecs_task_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.django.arn}:*"
        ]
      }
    ]
  })
}

locals {
  task_role_arn = var.task_role_arn != null ? var.task_role_arn : aws_iam_role.ecs_task_role[0].arn
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP FOR THE ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------

module "service_sg" {
  count  = var.service_sg_id == null ? 1 : 0
  source = "../sg"
  name   = "${var.name}-service"
  vpc_id = data.aws_vpc.selected.id
}

locals {
  service_sg_id = var.service_sg_id == null ? module.service_sg[0].id : var.service_sg_id
}

module "allow_outbound_all" {
  source            = "../sg-rule"
  security_group_id = local.service_sg_id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

module "allow_inbound_on_container_port" {
  source                   = "../sg-rule"
  security_group_id        = local.service_sg_id
  from_port                = var.container_port
  to_port                  = var.container_port
  source_security_group_id = local.alb_sg_id
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALB TO ROUTE TRAFFIC TO THE DJANGO SERVICE
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # An ALB can only be attached to one subnet per AZ, so filter the list of subnets to a unique one per AZ
  subnets_per_az  = { for subnet in data.aws_subnet.public : subnet.availability_zone => subnet.id... }
  subnets_for_alb = [for az, subnets in local.subnets_per_az : subnets[0]]
}

resource "aws_lb" "ecs" {
  name               = var.name
  load_balancer_type = "application"
  subnets            = local.subnets_for_alb
  security_groups    = [local.alb_sg_id]

  tags = {
    Name        = var.name
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = var.alb_port
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "ecs" {
  name_prefix = substr(var.name, 0, 6)
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  # Deregistration delay for graceful shutdown
  deregistration_delay = 30

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = var.name
    Environment = var.environment
  }
}

resource "aws_lb_listener_rule" "forward_all" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP FOR THE ALB
# ---------------------------------------------------------------------------------------------------------------------

module "alb_sg" {
  count  = var.alb_sg_id == null ? 1 : 0
  source = "../sg"
  name   = "${var.name}-alb"
  vpc_id = data.aws_vpc.selected.id
}

locals {
  alb_sg_id = var.alb_sg_id == null ? module.alb_sg[0].id : var.alb_sg_id
}

module "alb_allow_http_inbound" {
  source            = "../sg-rule"
  security_group_id = local.alb_sg_id
  from_port         = var.alb_port
  to_port           = var.alb_port
  cidr_blocks       = ["0.0.0.0/0"]
}

module "alb_allow_all_outbound" {
  source            = "../sg-rule"
  security_group_id = local.alb_sg_id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
