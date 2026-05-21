variable "name_prefix" {
  type = string
}

variable "enable_github_oidc" {
  type    = bool
  default = false
}

variable "github_repo" {
  type    = string
  default = "org/repo"
}

variable "ecr_repository_arn" {
  type    = string
  default = "*"
}

variable "tags" {
  type    = map(string)
  default = {}
}
