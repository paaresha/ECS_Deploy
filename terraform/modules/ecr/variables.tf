variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_retention_count" {
  description = "Number of images to retain in the repository"
  type        = number
  default     = 30
}

variable "allowed_principals" {
  description = "List of IAM principal ARNs allowed to push/pull"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
