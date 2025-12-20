TODO

- dodać badge: sec skany, helm CI
- co demonstruje, jakie technologie uzyte, odwołania do poszczególnych folderów
- założenia i wymagania do działania
- wymagane zmienne/sekrety
- jak w pełni zreplikować od 0 do działającego dev (np blokada pushu do maina, wymaganie PRów)
- local test serwisów z docker compose

# Microservices Demo - AWS Deployment

[![Terraform Apply](https://github.com/JustFiesta/microservices-deployment/actions/workflows/terraform-apply.yaml/badge.svg)](https://github.com/JustFiesta/microservices-deployment/actions/workflows/terraform-apply.yaml) [![Build](https://github.com/JustFiesta/microservices-deployment/actions/workflows/ci.yaml/badge.svg)](https://github.com/JustFiesta/microservices-deployment/actions/workflows/ci.yaml)

## About

This project demonstrates full DevOps automation for deploying a microservices application on AWS. It's based on [Google Cloud microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo), migrated to AWS infrastructure with complete CI/CD automation.

The goal is to showcase containerization, Kubernetes deployment, and modern DevOps practices including Infrastructure as Code, automated builds, security scanning, and GitOps principles.

### Technology Stack

| Category | Technologies |
|----------|-------------|
| **Cloud** | AWS (EKS, ECR, VPC, S3, IAM) |
| **Container** | Docker, Kubernetes, Crane |
| **IaC** | Terraform |
| **CI** | GitHub Actions, Composite Actions, Reusable Workflows |
| **CD** | ArgoCD, Helm |
| **Security** | Trivy, AWS Security Groups, IAM Boundary Policies |

## Project Structure

```
.
├── .github/                    # GitHub Actions workflows and custom actions
│   ├── actions/                # Reusable composite actions
│   └── workflows/              # CI/CD pipelines
├── microservices-demo/         # Application source code (12 microservices)
│   └── src/                    # Java, Go, Python, Node.js, C# services
└── terraform/                  # Infrastructure as Code
    └── environments/
        ├── dev/                # Dev environment (EKS + VPC + IAM)
        └── global/             # Shared resources (ECR repositories)
```

### Main Folders

| Folder | Purpose | Documentation |
|--------|---------|---------------|
| **`.github/`** | CI/CD workflows, deployment automation, security scanning | [.github/README.md](.github/README.md) |
| **`terraform/`** | AWS infrastructure definitions (EKS, VPC, ECR, IAM) | [terraform/README.md](terraform/README.md) |
| **`microservices-demo/src/`** | Googles' microservices-demo application  | [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) |

## Assumptions

### Architecture

- **Single ECR per project**: `terraform/environments/global/` creates ECR repositories shared across all environments
- **Single AWS account**: All resources deployed in one account (multi-account setup not implemented)
- **Main branch protected**: Direct pushes to `main` blocked, all changes via Pull Requests
- **One Terraform change per PR**: Workflows support modifying only one environment per PR (see [terraform/README.md](terraform/README.md) for details)

### CI/CD

- **PR-based builds**: Container images built on PR creation, not on merge to main
- **Automatic versioning**: Semantic versioning per service with auto-increment patch version
- **Manual promotion**: Images promoted between environments (dev->qa-tests→production-custom) via manual workflow dispatch
- **Dynamic environments**: Promotion workflow supports arbitrary environment names (dev, qa, prod, hotfix-YYYYMM, etc.)

## Pipelines

| Workflow | Trigger | Description |
|----------|---------|-------------|
| **ci.yaml** | PR to `main` (changes in `src/**`) | Build and push container images to ECR with auto-versioning |
| **terraform-ci.yaml** | PR (changes in `terraform/**`) | Validate, format, plan Terraform changes, post plan as PR comment |
| **terraform-apply.yaml** | Push to `main` (changes in `terraform/**`) | Automatically apply approved Terraform changes |
| **promote-image.yaml** | Manual (workflow_dispatch) | Promote images between environments (supports dynamic env names) |
| **security-scans.yaml** | Cron (Monday 6AM UTC) + manual | Weekly Trivy scan of all ECR images, upload to GitHub Security |

**Details**: See [.github/README.md](.github/README.md)

## Replication Guide

### Prerequisites

- AWS account with permissions for EKS, VPC, ECR, IAM
- GitHub repository (fork of this project)
- AWS CLI and Terraform CLI installed locally

### Steps

#### 1. Create S3 Backend

```bash
aws s3api create-bucket \
  --bucket <your-name>-kubernetes-tf-state-bucket \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

aws s3api put-bucket-versioning \
  --bucket <your-name>-kubernetes-tf-state-bucket \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket <your-name>-kubernetes-tf-state-bucket \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

#### 2. Configure Terraform Backend

Update `terraform/environments/*/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "<your-name>-kubernetes-tf-state-bucket"
    key    = "state/dev/terraform.tfstate"  # or global/
    region = "eu-west-1"
    encrypt = true
  }
}
```

#### 3. Set GitHub Secrets/Variables

**Repository Secrets** (Settings → Secrets and variables → Actions):

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**Repository Variables**:

- `AWS_REGION` (e.g., `eu-west-1`)
- `ECR_REGISTRY_URI` (e.g., `123456789012.dkr.ecr.eu-west-1.amazonaws.com/ecr-name`)
- `TERRAFORM_VERSION` (e.g., `1.9.0`)

#### 4. Update Local Variables

Edit `terraform/environments/dev/local-vars.tf` and `terraform/environments/global/local-vars.tf`:

```hcl
locals {
  project_name = "<your-name>-microservices-demo"
  tags = {
    env     = "dev"
    owner   = "<your-initials>"
    project = "k8s-microservices-demo"
  }
}
```

#### 5. Deploy Infrastructure

Create PR with Terraform changes:

```bash
git checkout -b terraform/initial-setup
git add terraform/
git commit -m "terraform: initial infrastructure setup"
git push origin terraform/initial-setup
```

Create PR → Review Terraform plan in PR comments → Merge to main → Automatic apply via workflows

To create new environments (qa, prod), copy `dev/` and adjust configuration (see [terraform/README.md](terraform/README.md))

#### TODO

- [ ] Install ArgoCD in EKS cluster
- [ ] Create Kubernetes manifests or Helm charts
- [ ] Configure ArgoCD application pointing to ECR images
- [ ] First deployment to cluster

## Troubleshooting

### Terraform Plan Fails in PR

**Problem**: Multiple environments changed, workflow fails

**Solution**: Workflows support only **one environment change per PR**. Modify `dev/` and `global/` in separate PRs.

**Why?**: Plan file naming conflict, clearer review process per environment.

### Image Not Found in Promotion

**Problem**: Promotion reports "Image not found"

**Solution**:

- Verify tag exists: `aws ecr list-images --repository-name <project>/<service>`

### EKS Cluster Creation Timeout

**Problem**: `terraform apply` timeout after 40 minutes

**Solution**:

- Check CloudFormation console (EKS uses CFN under the hood)
- Verify IAM permissions and permission boundaries
- Ensure VPC has correct DNS settings
