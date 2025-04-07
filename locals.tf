locals {
  # VPC - existing or new?
  vpc_id             = var.vpc_id == "" ?  module.vpc.vpc_id : var.vpc_id
  # 순서대로 확인해서 첫 번째로 "값이 있는" 리스트를 선택
  private_subnet_ids = coalescelist(module.vpc.private_subnets, var.private_subnet_ids, [""])
  public_subnet_ids  = coalescelist(module.vpc.public_subnets, var.public_subnet_ids, [""])

  # Atlantis
  atlantis_image = var.atlantis_image == "" ? "runatlantis/atlantis:${var.atlantis_version}" : var.atlantis_image
  atlantis_url = "https://${coalesce(
    element(concat(aws_route53_record.atlantis.*.fqdn, [""]), 0),
    module.alb.dns_name,
    "_"
  )}"
  atlantis_url_events = "${local.atlantis_url}/events"

  # Include only one group of secrets - for github, gitlab or bitbucket
  has_secrets = var.atlantis_gitlab_user_token != "" || var.atlantis_github_user_token != "" || var.atlantis_bitbucket_user_token != ""

  secret_name_key = local.has_secrets ? var.atlantis_gitlab_user_token != "" ? "ATLANTIS_GITLAB_TOKEN" : var.atlantis_github_user_token != "" ? "ATLANTIS_GH_TOKEN" : "ATLANTIS_BITBUCKET_TOKEN" : "unknown_secret_name_key"

  secret_name_value_from = local.has_secrets ? var.atlantis_gitlab_user_token != "" ? var.atlantis_gitlab_user_token_ssm_parameter_name : var.atlantis_github_user_token != "" ? var.atlantis_github_user_token_ssm_parameter_name : var.atlantis_bitbucket_user_token_ssm_parameter_name : "unknown_secret_name_value"

  secret_webhook_key = local.has_secrets ? var.atlantis_gitlab_user_token != "" ? "ATLANTIS_GITLAB_WEBHOOK_SECRET" : var.atlantis_github_user_token != "" ? "ATLANTIS_GH_WEBHOOK_SECRET" : "ATLANTIS_BITBUCKET_WEBHOOK_SECRET" : "unknown_secret_webhook_key"

  # Container definitions
  container_definitions = var.custom_container_definitions == "" ? var.atlantis_bitbucket_user_token != "" ? module.container_definition_bitbucket.json_map_encoded_list : module.container_definition_github_gitlab.json_map_encoded_list : var.custom_container_definitions

  container_definition_environment = [
    {
      name  = "ATLANTIS_ALLOW_REPO_CONFIG"
      value = var.allow_repo_config
    },
    {
      name  = "ATLANTIS_GITLAB_HOSTNAME"
      value = var.atlantis_gitlab_hostname
    },
    {
      name  = "ATLANTIS_LOG_LEVEL"
      value = "debug"
    },
    {
      name  = "ATLANTIS_PORT"
      value = var.atlantis_port
    },
    {
      name  = "ATLANTIS_ATLANTIS_URL"
      value = local.atlantis_url
    },
    {
      name  = "ATLANTIS_GH_USER"
      value = var.atlantis_github_user
    },
    {
      name  = "ATLANTIS_GITLAB_USER"
      value = var.atlantis_gitlab_user
    },
    {
      name  = "ATLANTIS_BITBUCKET_USER"
      value = var.atlantis_bitbucket_user
    },
    {
      name  = "ATLANTIS_BITBUCKET_BASE_URL"
      value = var.atlantis_bitbucket_base_url
    },
    {
      name  = "ATLANTIS_REPO_WHITELIST"
      value = join(",", var.atlantis_repo_whitelist)
    },
  ]

  # Secret access tokens
  container_definition_secrets_1 = [
    {
      name      = local.secret_name_key
      valueFrom = local.secret_name_value_from
    },
  ]

  # Webhook secrets are not supported by BitBucket
  container_definition_secrets_2 = [
    {
      name      = local.secret_webhook_key
      valueFrom = var.webhook_ssm_parameter_name
    },
  ]

  tags = merge(
    {
      "Name" = var.name
    },
    var.tags,
  )
}