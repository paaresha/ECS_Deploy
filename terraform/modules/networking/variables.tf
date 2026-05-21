variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "List of AZs to deploy subnets into"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateways for private subnet egress"
  type        = bool
  default     = true
}

variable "container_port" {
  description = "Port the container listens on (opened in ECS security group)"
  type        = number
  default     = 8080
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
