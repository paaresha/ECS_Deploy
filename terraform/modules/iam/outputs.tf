output "task_execution_role_arn" { value = aws_iam_role.task_execution.arn }
output "task_execution_role_name" { value = aws_iam_role.task_execution.name }
output "task_role_arn"           { value = aws_iam_role.task.arn }
output "task_role_name"          { value = aws_iam_role.task.name }
output "github_actions_role_arn" {
  value = var.enable_github_oidc ? aws_iam_role.github_actions["github"].arn : ""
}
