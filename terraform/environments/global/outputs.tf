# Output map of all ECR repository URLs
output "ecr_repository_urls" {
  description = "Map of service names to their ECR repository URLs"
  value = {
    for name, repo in aws_ecr_repository.microservices :
    name => repo.repository_url
  }
}

# Output just the registry URL (without repo paths)
output "ecr_registry_url" {
  description = "Base ECR registry URL"
  value = length(aws_ecr_repository.microservices) > 0 ? (
    split("/", values(aws_ecr_repository.microservices)[0].repository_url)[0]
  ) : ""
}

# Output list of all created repository names
output "ecr_repository_names" {
  description = "List of all ECR repository names"
  value       = [for repo in aws_ecr_repository.microservices : repo.name]
}

# Output count of discovered services
output "services_count" {
  description = "Number of microservices discovered and created in ECR"
  value       = length(local.services)
}
