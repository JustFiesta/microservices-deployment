#
# ECR
#
output "ecr_repository_url" {
  description = "Global ECR repository URL"
  value       = aws_ecr_repository.this.repository_url
}

output "ecr_repository_name" {
  description = "Global ECR repository name"
  value       = aws_ecr_repository.this.name
}
