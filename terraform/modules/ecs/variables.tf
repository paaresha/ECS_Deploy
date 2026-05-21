variable "name_prefix"            { type = string }
variable "service_name"           { type = string }
variable "environment"            { type = string }
variable "aws_region"             { type = string }

variable "vpc_id"                 { type = string }
variable "public_subnet_ids"      { type = list(string) }
variable "private_subnet_ids"     { type = list(string) }
variable "alb_sg_id"              { type = string }
variable "ecs_tasks_sg_id"        { type = string }

variable "task_execution_role_arn" { type = string }
variable "task_role_arn"           { type = string }

variable "container_image"         { type = string }
variable "container_port" {
  type    = number
  default = 8080
}

variable "app_version" {
  type    = string
  default = "latest"
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "min_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 10
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "alb_access_logs_bucket" {
  type    = string
  default = ""
}

variable "enable_exec_command" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
