TODO

- dlaczego tf?
- jak jest zorganizowane wszystko w tym folderze
- jaki flow wspiera (jak tworzyć envy, jak wykorzystywać moduły z plików, dlaczego dev jest auto-mode (booo moj aws inaczej nie działa, można je dostosowywać zgodnie z dokumentacjami wykorzystanych modułów od AWS))
- dlaczego global jest zawsze potrzebne
- jak ECR jest ogarniany (jeden dla wszystkich envow)
- jak używać/dodawać envy, edytować itp
- graf deva
- krótko, treściwie i technicznie

# Terraform Infrastructure

Documentation for AWS infrastructure managed by Terraform.

## Contents

```
terraform/
└── environments/
    ├── dev/                    # Dev environment (EKS + VPC + IAM)
    │   ├── backend.tf          # S3 backend configuration
    │   ├── providers.tf        # AWS provider setup
    │   ├── local-vars.tf       # Local variables and tags
    │   ├── vpc.tf              # VPC, subnets, NAT Gateway
    │   ├── iam.tf              # IAM roles for EKS cluster and nodes
    │   ├── eks.tf              # EKS cluster configuration
    │   └── outputs.tf          # Outputs (cluster endpoint, etc.)
    └── global/                 # Shared resources
        ├── backend.tf          # S3 backend configuration
        ├── providers.tf        # AWS provider setup
        ├── local-vars.tf       # Local variables
        ├── ecr.tf              # ECR repositories (auto-discovery)
        └── outputs.tf          # Outputs (repository URLs)
```

## Environments

### `global/` - Shared Resources

**Purpose**: Create resources shared across all environments. Without them workflows might not work.

**Resources**:

- **ECR Repositories**: Auto-discovered from microservices, one repository per service
  - Repository naming: `<project-name>/<service>` (e.g., `microservices-demo/frontend`)
  - Scanning: Auto-scan on push
  - Encryption: AES256
  - Lifecycle policies: Automatic cleanup of old images

**Why global?**

- Single ECR repository set shared across all environments
- Images promoted dev→qa→prod use same repositories
- Cost reduction (no image duplication)
- Simplified version management

**ECR Repository Structure**:

```
Full repository name: mbocak-microservices-demo/frontend
Full image URI:       910681227783.dkr.ecr.eu-west-1.amazonaws.com/mbocak-microservices-demo/frontend:1.2.3

Where:
  910681227783.dkr.ecr.eu-west-1.amazonaws.com   = Registry URI
  mbocak-microservices-demo                      = Project name (prefix)
  frontend                                       = Service name
  1.2.3                                          = Image tag
```

**Auto-Discovery (ecr.tf)**:

Terraform automatically discovers microservices by scanning for Dockerfiles:

```hcl
locals {
  microservices_path = "${path.root}/../../../microservices-demo/src"
  service_dirs       = fileset(local.microservices_path, "*/Dockerfile")
  services           = toset([for dir in local.service_dirs : dirname(dir)])
}

resource "aws_ecr_repository" "microservices" {
  for_each = local.services  # Dynamic!
  name     = "${local.project_name}/${each.key}"
}
```

**Process**:

1. Scans `microservices-demo/src/*/Dockerfile`
2. Finds: `frontend/`, `cartservice/`, `adservice/`, etc.
3. Creates ECR repository for each: `mbocak-microservices-demo/frontend`, etc.
4. Adding new service = add Dockerfile → Terraform auto-creates repository

**Lifecycle Policies**:

| Priority | Rule | Description |
|----------|------|-------------|
| 1 | Keep last 5 `dev-*` tags | Retain 5 newest dev versions |
| 2 | Expire untagged after 1 day | Remove build artifacts |
| 3 | Keep max 10 images | Catch-all limit |

**Why these policies?** Storage cost optimization, dev iterates quickly, untagged images are unnecessary intermediate layers.

### `dev/` - Development Environment

**Purpose**: Complete Kubernetes infrastructure for development.

**Resources**: VPC, EKS Cluster, IAM Roles - see files in `terraform/environments/dev/` for configuration details.

**Key Configuration**:

- VPC CIDR: `10.1.0.0/16` (2 AZs: eu-west-1a, eu-west-1b)
- EKS version: `1.34`
- Single NAT Gateway (cost optimization for dev)
- Public endpoint (dev convenience)

**For production environments**: Use multi-AZ NAT Gateway, private endpoint, and production node pools.

## How to Use

### Initial Setup and Deployment

See [Main README](../README.md#replication-guide) for complete setup instructions including:
- Creating S3 backend
- Configuring GitHub secrets/variables
- Deploying infrastructure via workflows

### Adding New Environment (qa, prod)

#### 1. Copy dev environment

```bash
cd terraform/environments
cp -r dev qa
```

#### 2. Update configuration

```hcl
# terraform/environments/qa/backend.tf
terraform {
  backend "s3" {
    key = "state/qa/terraform.tfstate"  # Change
  }
}

# terraform/environments/qa/local-vars.tf
locals {
  tags = {
    env = "qa"  # Change
  }
}

# terraform/environments/qa/vpc.tf
cidr = "10.2.0.0/16"  # Change CIDR
```

**Recommended VPC CIDRs**:

- Dev: `10.1.0.0/16`
- QA: `10.2.0.0/16`
- Prod: `10.3.0.0/16`

#### 3. Adjust resources for environment

### Modifying Existing Environment

**Deploy via GitHub Workflows** (recommended):

```bash
git checkout -b terraform/upgrade-eks
vim terraform/environments/dev/eks.tf
git add terraform/
git commit -m "terraform(dev): upgrade EKS to 1.35"
git push origin terraform/upgrade-eks

# Create PR → Review plan in comments → Merge → Automatic apply
```

See [.github/README.md](../.github/README.md) for workflow details.

### Connect to EKS

```bash
aws eks update-kubeconfig \
  --region eu-west-1 \
  --name <project-name>-microservices-demo

kubectl cluster-info
kubectl get nodes
```

## Constraints

### One Environment Per PR

**Constraint**: Workflows support only one environment change per PR.

**Reason**: Plan file naming conflict, clearer review process.

**Solution**: Create separate PRs for each environment.

See [Main README - Assumptions](../README.md#assumptions) and [.github/README.md - Workflow Constraints](../.github/README.md#workflow-constraints) for details.

## Pipeline Integration

Pipelines auto-discover environments in `terraform/environments/`:

- Auto-discovery of changed environments
- Automatic `terraform fmt` and `validate`
- Auto-apply after merge to main

**Required GitHub Variables per environment**:

- Format: `<ENV_NAME>_ECR_REGISTRY_URI`
- Example: `DEV_ECR_REGISTRY_URI=910681227783.dkr.ecr.eu-west-1.amazonaws.com/mbocak-microservices-demo`

Note: The variable should include the project name prefix (e.g., `/mbocak-microservices-demo`), not just the registry URL.

See [.github/README.md](../.github/README.md) for complete workflow documentation.

## Related Documentation

- [Main README](../README.md) - Project overview and setup guide
- [.github/README.md](../.github/README.md) - CI/CD workflows
- [Terraform AWS Modules](https://registry.terraform.io/namespaces/terraform-aws-modules) - Module documentation
