terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "cicd-demo/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "cicd-demo"
      Environment = "prod"
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state = "available" }

module "networking" {
  source = "../../modules/networking"

  name_prefix          = "${var.project_name}-${var.environment}"
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 3)
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
  image_retention_count = 50
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

  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  alb_sg_id          = module.networking.alb_sg_id
  ecs_tasks_sg_id    = module.networking.ecs_tasks_sg_id

  task_execution_role_arn = module.iam.task_execution_role_arn
  task_role_arn           = module.iam.task_role_arn

  container_image = "${module.ecr.repository_url}:latest"
  container_port  = 8080
  app_version     = var.git_commit

  task_cpu      = 512
  task_memory   = 1024
  desired_count = 3
  min_capacity  = 2
  max_capacity  = 20

  log_retention_days  = 90
  enable_exec_command = false

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
