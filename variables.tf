variable "region" {
  type    = string
  default = ""
}

variable "name" {
  description = "VPC, ALB 기타 등등 이름"
  type        = string
  default     = "atlantis"
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}

# VPC
variable "vpc_id" {
  description = "존재하는 VPC의 ID, 만약 없으면 생성"
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "VPC내부의 public subnet id list"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "VPC내부의 private subnet id list"
  type        = list(string)
  default     = []
}

variable "cidr" {
  description = "`vpc_id`가 지정되지 않은 경우 생성될 VPC의 CIDR 블록"
  type        = string
  default     = ""
}

variable "azs" {
  description = "리전 내 가용 영역 목록"
  type        = list(string)
  default     = []
}

variable "public_subnets" {
  description = "VPC 내부의 퍼블릭 서브넷 목록"
  type        = list(string)
  default     = []
}

variable "private_subnets" {
  description = "VPC 내부의 프라이빗 서브넷 목록"
  type        = list(string)
  default     = []
}

# ALB
variable "alb_ingress_cidr_blocks" {
  description = "ALB의 모든 인그레스 규칙에 사용할 IPv4 CIDR 범위 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_log_bucket_name" {
  description = "로드 밸런서 액세스 로그를 저장하기 위한 S3 버킷(외부에서 생성됨). alb_logging_enabled가 true인 경우 필수"
  type        = string
  default     = ""
}

variable "alb_log_location_prefix" {
  description = "로그가 저장되는 log_bucket_name 내의 S3 접두사"
  type        = string
  default     = ""
}

variable "alb_logging_enabled" {
  description = "ALB가 S3에 요청을 기록할지 여부를 제어"
  type        = bool
  default     = false
}

variable "alb_enable_deletion_protection" {
  description = "ALB 삭제 방지 옵션션"
  type        = bool
  default     = false
}

# ACM
variable "certificate_arn" {
  description = "AWS ACM에서 발급한 인증서의 ARN. 비어 있으면 Route53 DNS를 사용하여 새 ACM 인증서가 생성되고 검증됨"
  type        = string
  default     = ""
}

variable "acm_certificate_domain_name" {
  description = "ACM 인증서에 사용할 Route53 도메인 이름. 이 도메인에 대한 Route53 존은 미리 생성되어 있어야 함. route53_zone_name의 값과 다를 경우 지정"
  type        = string
  default     = ""
}

# Route53
variable "route53_zone_name" {
  description = "ACM 인증서를 생성하고 메인 A-레코드를 설정할 Route53 존 이름, 끝에 점 제외"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  type    = string
  default = ""
}

variable "create_route53_record" {
  description = "Atlantis에 대한 Route53 레코드를 생성할지 여부"
  type        = bool
  default     = false
}

# Cloudwatch
variable "cloudwatch_log_retention_in_days" {
  description = "Atlantis CloudWatch 로그의 보존 기간"
  type        = number
  default     = 7
}

# SSM parameters for secrets
variable "webhook_ssm_parameter_name" {
  description = "웹훅 비밀을 저장할 SSM 파라미터 이름"
  type        = string
  default     = "/atlantis/webhook/secret"
}

variable "atlantis_github_user_token_ssm_parameter_name" {
  description = "atlantis_github_user_token을 저장할 SSM 파라미터 이름"
  type        = string
  default     = "/atlantis/github/user/token"
}

variable "atlantis_gitlab_user_token_ssm_parameter_name" {
  description = "atlantis_gitlab_user_token을 저장할 SSM 파라미터 이름"
  type        = string
  default     = "/atlantis/gitlab/user/token"
}

variable "atlantis_bitbucket_user_token_ssm_parameter_name" {
  description = "atlantis_bitbucket_user_token을 저장할 SSM 파라미터 이름"
  type        = string
  default     = "/atlantis/bitbucket/user/token"
}

variable "ssm_kms_key_arn" {
  description = "SSM 파라미터의 암호화 및 복호화에 사용할 KMS 키의 ARN. 기본 키가 아닌 사용자 지정 KMS 키를 사용하는 경우에만 필요"
  type        = string
  default     = ""
}

# ECS Service / Task
variable "ecs_service_assign_public_ip" {
  description = "ECS 서비스가 퍼블릭 서브넷을 사용하는 경우 true로 설정해야 함 (자세한 내용: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_cannot_pull_image.html)"
  type        = bool
  default     = false
}

variable "policies_arn" {
  description = "적용하려는 정책의 ARN 목록"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

variable "ecs_service_desired_count" {
  description = "태스크 정의의 인스턴스 수를 배치하고 계속 실행할 개수"
  type        = number
  default     = 1
}

variable "ecs_service_deployment_maximum_percent" {
  description = "배포 중 서비스에서 실행 중일 수 있는 태스크 수의 상한선 (서비스의 desiredCount의 백분율로 표현)"
  type        = number
  default     = 200
}

variable "ecs_service_deployment_minimum_healthy_percent" {
  description = "배포 중 서비스에서 실행 중이고 정상 상태를 유지해야 하는 태스크 수의 하한선 (서비스의 desiredCount의 백분율로 표현)"
  type        = number
  default     = 50
}

variable "ecs_task_cpu" {
  description = "태스크에서 사용하는 CPU 유닛 수"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "태스크에서 사용하는 메모리 양 (MiB 단위)"
  type        = number
  default     = 512
}

variable "container_memory_reservation" {
  description = "컨테이너에 예약할 메모리 양 (MiB 단위)"
  type        = number
  default     = 128
}

variable "custom_container_definitions" {
  description = "단일 유효한 JSON 문서로 제공되는 유효한 컨테이너 정의 목록. 기본적으로 표준 컨테이너 정의가 사용됨"
  type        = string
  default     = ""
}

# Atlantis
variable "atlantis_image" {
  description = "Atlantis 실행용 Docker 이미지. 미지정 시 공식 이미지 사용."
  type        = string
  default     = ""
}

variable "atlantis_version" {
  description = "Atlantis 실행 버전. 미지정 시 최신 버전 사용."
  type        = string
  default     = "latest"
}

variable "atlantis_port" {
  description = "Atlantis 실행 포트. 기본값이면 충분."
  type        = number
  default     = 4141
}

variable "atlantis_repo_whitelist" {
  description = "Atlantis 허용 리포지토리 목록."
  type        = list(string)
}

variable "atlantis_allowed_repo_names" {
  description = "웹훅 생성용 Github 리포지토리."
  type        = list(string)
  default     = []
}

variable "allow_repo_config" {
  description = "true 시 atlantis.yaml 사용 허용."
  type        = string
  default     = "true"
}


# Github
variable "atlantis_github_user" {
  description = "Atlantis 명령 실행용 GitHub 사용자 이름."
  type        = string
  default     = ""
}

variable "atlantis_github_user_token" {
  description = "Atlantis 명령 실행용 GitHub 사용자 토큰."
  type        = string
}

# Gitlab
variable "atlantis_gitlab_user" {
  description = "Atlantis 명령 실행용 Gitlab 사용자 이름."
  type        = string
  default     = ""
}

variable "atlantis_gitlab_user_token" {
  description = "Atlantis 명령 실행용 Gitlab 사용자 토큰."
  type        = string
  default     = ""
}

variable "atlantis_gitlab_hostname" {
  description = "Gitlab 서버 호스트명. 기본값은 gitlab.com."
  type        = string
  default     = "gitlab.com"
}

# Bitbucket
variable "atlantis_bitbucket_user" {
  description = "Atlantis 명령 실행용 Bitbucket 사용자 이름."
  type        = string
  default     = ""
}

variable "atlantis_bitbucket_user_token" {
  description = "Atlantis 명령 실행용 Bitbucket 사용자 토큰."
  type        = string
  default     = ""
}

variable "atlantis_bitbucket_base_url" {
  description = "Bitbucket 서버 기본 URL. 온프렘(Stash)용."
  type        = string
  default     = ""
}

variable "custom_environment_secrets" {
  description = "컨테이너가 사용할 추가 비밀 목록 (`name`과 `valueFrom`이 포함된 맵 리스트)."
  type        = list(map(string))
  default     = []
}

variable "custom_environment_variables" {
  description = "컨테이너가 사용할 추가 환경 변수 목록 (`name`과 `value`가 포함된 맵 리스트)."
  type        = list(map(string))
  default     = []
}

variable "security_group_ids" {
  description = "로드 밸런서에 추가할 보안 그룹 목록."
  type        = list(string)
  default     = []
}

variable "aws_ssm_path" {
  description = "SSM용 AWS ARN 접두어 (공용 AWS 지역 또는 Govcloud). 유효 옵션: aws, aws-us-gov."
  type        = string
  default     = "aws"
}

# backend
variable "backend_dynamo_table_name" {
  type    = string
  default = ""
}
variable "backend_bucket_name" {
  type    = string
  default = ""
}
variable "backend_key" {
  type    = string
  default = ""
}
variable "backend_encrypt" {
  type    = bool
  default = true
}
