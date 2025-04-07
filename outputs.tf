output "atlantis_url" {
  description = "Atlantis URL."
  value       = local.atlantis_url
}

output "atlantis_url_events" {
  description = "Atlantis 웹훅 이벤트 URL."
  value       = local.atlantis_url_events
}

output "atlantis_allowed_repo_names" {
  description = "웹훅 생성용 Github 리포지토리."
  value       = var.atlantis_allowed_repo_names
}

output "task_role_arn" {
  description = "Atlantis ECS 태스크 역할 ARN."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "vpc_id" {
  description = "생성되거나 입력된 VPC ID."
  value       = local.vpc_id
}

output "webhook_secret" {
  description = "웹훅 시크릿."
  value       = element(concat(random_id.webhook.*.hex, [""]), 0)
}

output "alb_dns_name" {
  description = "ALB DNS 이름."
  value       = module.alb.dns_name
}

output "ecs_assis_task_definition" {
  description = "ECS 서비스용 태스크 정의 (외부 트리거용)."
  value       = aws_ecs_service.atlantis.task_definition
}
