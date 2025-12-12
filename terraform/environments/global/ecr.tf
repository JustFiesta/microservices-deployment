# Automatically discover all microservices that have Dockerfiles
locals {
  # Path to microservices source directory (relative to terraform root)
  microservices_path = "${path.root}/../../../microservices-demo/src"
  
  # Get all directories that contain Dockerfile
  service_dirs = fileset(local.microservices_path, "*/Dockerfile")
  
  # Extract service names (remove /Dockerfile suffix)
  services = toset([for dir in local.service_dirs : dirname(dir)])
}

# Create ECR repository for each discovered microservice
resource "aws_ecr_repository" "microservices" {
  for_each = local.services
  
  name = "${local.project_name}/${each.key}"
  
  image_scanning_configuration {
    scan_on_push = true  # Auto-scan on push
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = merge(local.tags, {
    service = each.key
    managed = "terraform"
  })
}

# Lifecycle policy for each microservice repository
resource "aws_ecr_lifecycle_policy" "microservices_retention" {
  for_each = aws_ecr_repository.microservices
  
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 dev-* tagged images per service"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev-"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 production semver images (any version format)"
        selection = {
          tagStatus   = "tagged"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Expire untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countNumber = 1
          countUnit   = "days"
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
