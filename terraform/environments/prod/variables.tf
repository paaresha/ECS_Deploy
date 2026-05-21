variable "aws_region"   { type = string; default = "us-east-1" }
variable "environment"  { type = string; default = "prod" }
variable "project_name" { type = string; default = "cicd-demo" }
variable "github_repo"  { type = string; default = "your-org/your-repo" }
variable "git_commit"   { type = string; default = "local" }
