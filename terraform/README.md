# Terraform Infrastructure

This directory contains Terraform configurations for deploying AWS EKS infrastructure across multiple environments, for `microservices-demo` application.

## Directory Structure

```shell
terraform/
└── environments/
    ├── dev/
    │   ├── backend.tf       # S3 backend configuration
    │   ├── providers.tf     # AWS provider setup
    │   ├── local-vars.tf    # Environment-specific variables
    │   ├── vpc.tf          # VPC and networking
    │   ├── eks.tf          # EKS cluster configuration
    │   ├── ecr.tf          # ECR repositories
    │   ├── iam.tf          # IAM roles and policies
    │   └── outputs.tf      # Terraform outputs
    └── [other environments]/
```

## How to Create a New Environment

To create a new environment (e.g., `staging`, `prod`):

### 1. Copy Existing Environment

```bash
cp -r terraform/environments/dev terraform/environments/<env-name>
```

### 2. Create S3 bucket for environment

### 3. Update `backend.tf`

Change the state file key for the new environment:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-tf-state-bucket" # Update this
    key            = "state/<env-name>/terraform.tfstate"  # Update this
    region         = "eu-west-1" # Update this
    encrypt        = true
  }
}
```

### 4. Update `local-vars.tf`

Configure environment-specific variables:

```hcl
locals {
  tags = {
    env     = "<env-name>"   # Update this
    owner   = "your-name"    # Update this
    project = "project-name" # Update this
  }

  # Ensure cluster_name is 1-38 characters (AWS limitation)
  cluster_name = "${local.project_name}"
}
```

### 5. Test

```bash
cd terraform/environments/<env-name>
terraform init
terraform fmt -recursive
terraform plan
```

### 6. Pipeline Integration

The Terraform CI/CD pipelines automatically discover all environments in `terraform/environments/`:

- **Changes detected**: Pipelines scan `terraform/environments/**` for modifications
- **Validation and Plan**: Pipelines automatically check integrity of HCL
- **Auto Format**: Pipeline automatically formats code and pushes formatted files into current branch if needed
- **Parallel execution**: Each environment is processed independently
- **Auto-apply**: Merges to `main` trigger automatic deployment

No additional pipeline configuration needed.

### 7. Add ECR secret for created environment

Pipelines for security and CI reqiure destigneted ECR variables per environment in given convention: `<ENV_NAME>_ECR_REGISTRY`, eg. `DEV_ECR_REGISTRY`.

This enables them to check correcponsind environment repository - without them they will not work.

## How to connect to EKS

```shell
# configure awscli with credentials for AWS Account where resources are created
aws configure 

# update kubeconfig for cluster
aws eks update-kubeconfig \
  --region <region> \
  --name <created_cluster_name>

# check cluster info
kubectl cluster-info 

# check if node group was added correctly
kubectl get nodes 

# check if pods can be created successfully
kubectl run test-nginx --image=nginx
kubectl get pods -o wide
```
