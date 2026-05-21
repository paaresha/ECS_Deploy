terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "cicd-demo"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state = "available" }

module "networking" {
  source = "../../modules/networking"

  name_prefix          = "${var.project_name}-${var.environment}"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 2)
  enable_nat_gateway   = true
  container_port       = 8080

  tags = {
    Project     = var.project_name
    Environment = var.environment
    GitCommit   = var.git_commit
  }
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name       = "${var.project_name}-api"
  image_retention_count = 20
  allowed_principals    = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    GitCommit   = var.git_commit
  }
}

module "iam" {
  source = "../../modules/iam"

  name_prefix        = "${var.project_name}-${var.environment}"
  enable_github_oidc = true
  github_repo        = var.github_repo
  ecr_repository_arn = module.ecr.repository_arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    GitCommit   = var.git_commit
  }
}

module "ecs" {
  source = "../../modules/ecs"

  name_prefix  = "${var.project_name}-${var.environment}"
  service_name = "${var.project_name}-api"
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_id                 = module.networking.vpc_id
  public_subnet_ids      = module.networking.public_subnet_ids
  private_subnet_ids     = module.networking.private_subnet_ids
  alb_sg_id              = module.networking.alb_sg_id
  ecs_tasks_sg_id        = module.networking.ecs_tasks_sg_id
  alb_access_logs_bucket = var.alb_access_logs_bucket

  task_execution_role_arn = module.iam.task_execution_role_arn
  task_role_arn           = module.iam.task_role_arn

  container_image = "${module.ecr.repository_url}:latest"
  container_port  = 8080
  app_version     = var.git_commit

  task_cpu      = 256
  task_memory   = 512
  desired_count = 1
  min_capacity  = 1
  max_capacity  = 3

  log_retention_days  = 14
  enable_exec_command = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
    GitCommit   = var.git_commit
  }
}

output "ecr_repository_url"  { value = module.ecr.repository_url }
output "alb_dns_name"        { value = module.ecs.alb_dns_name }
output "ecs_cluster_name"    { value = module.ecs.cluster_name }
output "ecs_service_name"    { value = module.ecs.service_name }
output "task_family"         { value = module.ecs.task_family }
output "github_actions_role" { value = module.iam.github_actions_role_arn }
