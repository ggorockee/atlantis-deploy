

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "this" {
  count = var.create_route53_record ? 1 : 0

  name         = var.route53_zone_name
  private_zone = false
}

###################
# Secret for webhook
###################
resource "random_id" "webhook" {
  byte_length = "64"
}

resource "aws_ssm_parameter" "webhook" {
  count = var.atlantis_bitbucket_user_token != "" ? 0 : 1

  name  = var.webhook_ssm_parameter_name
  type  = "SecureString"
  value = random_id.webhook.hex
}

resource "aws_ssm_parameter" "atlantis_github_user_token" {
  count = var.atlantis_github_user_token != "" ? 1 : 0

  name  = var.atlantis_github_user_token_ssm_parameter_name
  type  = "SecureString"
  value = var.atlantis_github_user_token
}

resource "aws_ssm_parameter" "atlantis_gitlab_user_token" {
  count = var.atlantis_gitlab_user_token != "" ? 1 : 0

  name  = var.atlantis_gitlab_user_token_ssm_parameter_name
  type  = "SecureString"
  value = var.atlantis_gitlab_user_token
}

resource "aws_ssm_parameter" "atlantis_bitbucket_user_token" {
  count = var.atlantis_bitbucket_user_token != "" ? 1 : 0

  name  = var.atlantis_bitbucket_user_token_ssm_parameter_name
  type  = "SecureString"
  value = var.atlantis_bitbucket_user_token
}

###################
# VPC
###################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v5.12.1"

  create_vpc = var.vpc_id == ""

  name = var.name

  cidr            = var.cidr
  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

###################
# ALB
###################
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "v9.11.0"

  name = var.name

  vpc_id          = local.vpc_id
  subnets         = local.public_subnet_ids
  security_groups = flatten([module.alb_https_sg.security_group_id, module.alb_http_sg.security_group_id, var.security_group_ids])

  enable_deletion_protection = var.alb_enable_deletion_protection

  access_logs = {
    bucket  = var.alb_log_bucket_name
    enabled = var.alb_logging_enabled
    prefix  = var.alb_log_location_prefix
  }

  listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = var.certificate_arn == "" ? module.acm.acm_certificate_arn : var.certificate_arn
      forward = {
        target_group_key = "target"
      }
    },
    {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    },
  ]

  target_groups = {
    target = {
      # name_prefix                 = "target"
      backend_protocol     = "HTTP"
      backend_port         = var.atlantis_port
      create_attachment    = false
      target_type          = "ip"
      deregistration_delay = 10
    }
  }

  tags = local.tags
}

###################
# Security groups
###################
module "alb_https_sg" {
  source  = "terraform-aws-modules/security-group/aws//modules/https-443"
  version = "v5.1.2"

  name        = "${var.name}-alb-https"
  vpc_id      = local.vpc_id
  description = "Security group with HTTPS ports open for specific IPv4 CIDR block (or everybody), egress ports are all world open"

  ingress_cidr_blocks = var.alb_ingress_cidr_blocks

  tags = local.tags
}

module "alb_http_sg" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "v5.1.2"

  name        = "${var.name}-alb-http"
  vpc_id      = local.vpc_id
  description = "Security group with HTTP ports open for specific IPv4 CIDR block (or everybody), egress ports are all world open"

  ingress_cidr_blocks = var.alb_ingress_cidr_blocks

  tags = local.tags
}

module "atlantis_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "v5.1.2"

  name        = var.name
  vpc_id      = local.vpc_id
  description = "Security group with open port for Atlantis (${var.atlantis_port}) from ALB, egress ports are all world open"

  computed_ingress_with_source_security_group_id = [
    {
      from_port                = var.atlantis_port
      to_port                  = var.atlantis_port
      protocol                 = "tcp"
      description              = "Atlantis"
      source_security_group_id = module.alb_https_sg.security_group_id
    },
  ]

  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = local.tags
}

###################
# ACM (SSL certificate)
###################
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "v5.1.0"

  create_certificate = var.certificate_arn == ""

  domain_name = var.acm_certificate_domain_name == "" ? join(".", [var.name, var.route53_zone_name]) : var.acm_certificate_domain_name

  validation_method = "DNS"

  # zone_id = var.certificate_arn == "" ? element(concat(data.aws_route53_zone.this.*.id, [""]), 0) : ""
  zone_id = var.route53_zone_id
  tags    = local.tags
}

###################
# Route53 record
###################
resource "aws_route53_record" "atlantis" {
  zone_id = var.route53_zone_id
  name    = var.name
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

###################
# ECS
###################
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "v5.11.4"

  cluster_name = var.name
}

data "aws_iam_policy_document" "ecs_tasks" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.name}-ecs_task_execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  count = length(var.policies_arn)

  role       = aws_iam_role.ecs_task_execution.id
  policy_arn = element(var.policies_arn, count.index)
}

// ref: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data.html
data "aws_iam_policy_document" "ecs_task_access_secrets" {
  statement {
    effect = "Allow"

    resources = [
      "arn:${var.aws_ssm_path}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.webhook_ssm_parameter_name}",
      "arn:${var.aws_ssm_path}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.atlantis_github_user_token_ssm_parameter_name}",
      "arn:${var.aws_ssm_path}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.atlantis_gitlab_user_token_ssm_parameter_name}",
      "arn:${var.aws_ssm_path}:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.atlantis_bitbucket_user_token_ssm_parameter_name}",
    ]

    actions = [
      "ssm:GetParameters",
      "secretsmanager:GetSecretValue",
    ]
  }
}

data "aws_iam_policy_document" "ecs_task_access_secrets_with_kms" {
  count = var.ssm_kms_key_arn == "" ? 0 : 1

  source_policy_documents = [data.aws_iam_policy_document.ecs_task_access_secrets.json]

  statement {
    sid       = "AllowKMSDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.ssm_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_access_secrets" {
  count = var.atlantis_github_user_token != "" || var.atlantis_gitlab_user_token != "" || var.atlantis_bitbucket_user_token != "" ? 1 : 0

  name = "ECSTaskAccessSecretsPolicy"

  role = aws_iam_role.ecs_task_execution.id

  policy = element(
    compact(
      concat(
        data.aws_iam_policy_document.ecs_task_access_secrets_with_kms.*.json,
        data.aws_iam_policy_document.ecs_task_access_secrets.*.json,
      ),
    ),
    0,
  )
}

module "container_definition_github_gitlab" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "v0.61.1"

  container_name  = var.name
  container_image = local.atlantis_image

  container_cpu                = var.ecs_task_cpu
  container_memory             = var.ecs_task_memory
  container_memory_reservation = var.container_memory_reservation

  port_mappings = [
    {
      containerPort = var.atlantis_port
      hostPort      = var.atlantis_port
      protocol      = "tcp"
    },
  ]
  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = data.aws_region.current.name
      "awslogs-group"         = aws_cloudwatch_log_group.atlantis.name
      "awslogs-stream-prefix" = "ecs"
    }
  }

  environment = concat(
    local.container_definition_environment,
    var.custom_environment_variables,
  )

  secrets = concat(
    local.container_definition_secrets_1,
    local.container_definition_secrets_2,
    var.custom_environment_secrets,
  )
}

module "container_definition_bitbucket" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "v0.61.1"

  container_name  = var.name
  container_image = local.atlantis_image

  container_cpu                = var.ecs_task_cpu
  container_memory             = var.ecs_task_memory
  container_memory_reservation = var.container_memory_reservation

  port_mappings = [
    {
      containerPort = var.atlantis_port
      hostPort      = var.atlantis_port
      protocol      = "tcp"
    },
  ]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = data.aws_region.current.name
      "awslogs-group"         = aws_cloudwatch_log_group.atlantis.name
      "awslogs-stream-prefix" = "ecs"
    }
  }

  environment = concat(
    local.container_definition_environment,
    var.custom_environment_variables,
  )

  secrets = concat(
    local.container_definition_secrets_1,
    var.custom_environment_secrets,
  )
}

resource "aws_ecs_task_definition" "atlantis" {
  family                   = var.name
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory

  container_definitions = local.container_definitions
}

data "aws_ecs_task_definition" "atlantis" {
  task_definition = var.name

  depends_on = [aws_ecs_task_definition.atlantis]
}

resource "aws_ecs_service" "atlantis" {
  name    = var.name
  cluster = module.ecs.cluster_id
  task_definition = "${data.aws_ecs_task_definition.atlantis.family}:${max(
    aws_ecs_task_definition.atlantis.revision,
    data.aws_ecs_task_definition.atlantis.revision,
  )}"
  desired_count                      = var.ecs_service_desired_count
  launch_type                        = "FARGATE"
  deployment_maximum_percent         = var.ecs_service_deployment_maximum_percent
  deployment_minimum_healthy_percent = var.ecs_service_deployment_minimum_healthy_percent

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [module.atlantis_sg.security_group_id]
    assign_public_ip = var.ecs_service_assign_public_ip
  }

  load_balancer {
    container_name   = var.name
    container_port   = var.atlantis_port
    target_group_arn = module.alb.target_groups["target"].arn
  }
}

###################
# Cloudwatch logs
###################
resource "aws_cloudwatch_log_group" "atlantis" {
  name              = var.name
  retention_in_days = var.cloudwatch_log_retention_in_days

  tags = local.tags
}
