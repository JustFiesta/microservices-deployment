resource "aws_ecr_repository" "this" {
  name = local.project_name
  tags = local.tags
}


resource "aws_ecr_lifecycle_policy" "retency_policy" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 tagged images (multi-arch safe)"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["invoice-"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
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