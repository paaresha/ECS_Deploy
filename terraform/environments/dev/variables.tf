variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "project_name" {
  type    = string
  default = "cicd-demo"
}
variable "github_repo" {
  type    = string
  default = "your-org/your-repo"
}
variable "git_commit" {
  type    = string
  default = "local"
}
variable "alb_access_logs_bucket" {
  description = "S3 bucket name for ALB access logs"
  type        = string
}
