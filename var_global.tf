variable "aws_region" {
  default = "ap-northeast-2"
}

variable "assume_role_arn" {
  description = "AWS API 접근 시 맡을 역할."
  default     = ""
}

# Atlantis user
variable "atlantis_user" {
  description = "Atlantis 명령 실행 사용자 이름. 역할 맡을 때 세션 이름으로 사용. 자세한 내용 - https://github.com/runatlantis/atlantis#assume-role-session-names"
  default     = "atlantis_user"
}

# Account IDs
# Add all account ID to here 
variable "account_id" {
  type = string
}

# Remote State that will be used when creating other resources
# You can add any resource here, if you want to refer from others
variable "remote_state" {
  default = {
  }
}
