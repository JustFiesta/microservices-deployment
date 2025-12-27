# Microservices Demo - AWS Deployment

[![Terraform Apply](https://github.com/JustFiesta/microservices-deployment/actions/workflows/terraform-apply.yaml/badge.svg)](https://github.com/JustFiesta/microservices-deployment/actions/workflows/terraform-apply.yaml) [![Build](https://github.com/JustFiesta/microservices-deployment/actions/workflows/ci.yaml/badge.svg)](https://github.com/JustFiesta/microservices-deployment/actions/workflows/ci.yaml) [![Helm Chart CI](https://github.com/JustFiesta/microservices-deployment/actions/workflows/helm-ci.yaml/badge.svg)](https://github.com/JustFiesta/microservices-deployment/actions/workflows/helm-ci.yaml) [![Security Scans](https://github.com/JustFiesta/microservices-deployment/actions/workflows/security-scans.yaml/badge.svg)](https://github.com/JustFiesta/microservices-deployment/actions/workflows/security-scans.yaml)

This project demonstrates a complete DevOps automation pipeline for deploying a microservices application on AWS. Based on [Google Cloud's microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo), it showcases modern cloud-native practices and enterprise-grade CI/CD workflows.

Focus went to ease the collaboration of developers and operators. Mundane tasks are automated, checks are perfomed automatically, so the information might flow from one to the other. Quality and small batches are enforced, no main branch pushes are acceptable, PRs are main way of communicating.  
Made with flexible approach such as DRY/KISS, can be modified easily (more envs, reusable workflows, versioning changes, etc.)

Made as a demonstation/educational - not expected to be used in real world, but can be nontheless.

**What This Project Demonstrates**:

- **Full GitOps Workflow**: Pull Request-based deployments with ArgoCD continuous delivery
- **Infrastructure as Code**: Terraform-managed AWS resources (EKS, VPC, ECR, IAM) with automated planning and apply
- **Containerization**: Multi-language microservices (12 services: Java, Go, Python, Node.js, C#) packaged as minimal Docker images
- **Shift-left Security**: Automated Trivy vulnerability scanning, IAM boundary policies
- **Multi Environment Support**: Many environments can be created with not normative naming scheme. Workflows base on directory names.
- **Environment Promotion**: Controlled image promotion across environments (dev > test-qa > prod) with semantic versioning
- **Automated Testing**: Local development with docker-compose, Helm chart validation with Kubeconform
- **Modular CI/CD**: Reusable GitHub Actions workflows and composite actions following DRY principles
- **Changes detection**: Terraform and image workflows detect only changed environments/services

## Technology Stack

| Category | Technologies |
|----------|-------------|
| **Cloud Provider** | AWS (EKS, ECR, VPC, S3, IAM, CloudFormation) |
| **Container Orchestration** | Kubernetes 1.34 (EKS), Docker |
| **Infrastructure as Code** | Terraform 1.9+ with S3 backend, terraform-aws-modules |
| **CI Pipeline** | GitHub Actions (Composite Actions, Reusable Workflows, Matrix Builds) |
| **CD & GitOps** | ArgoCD (automated sync, self-heal), Helm 3.14+ |
| **Container Registry** | Amazon ECR (auto-discovery, lifecycle policies) |
| **Image Management** | Crane (metadata-only promotions), Semantic Versioning |
| **Security Scanning** | Trivy (SARIF integration, weekly scans) |
| **Security Controls** | IAM Boundary Policies, Security Groups |
| **Local Development** | Docker Compose (12 microservices) |
| **Validation Tools** | Kubeconform (Kubernetes manifest validation) |
| **Application Languages** | Go, Java, Python, Node.js, C# (.NET) |

---

## Project Structure

```shell
.
├── .github/                       # GitHub Actions CI/CD automation
│   ├── actions/                   # Composite actions (Terraform init/validate/plan)
│   └── workflows/                 # Main workflows + reusable discovery workflows
├── argocd/                        # ArgoCD Application manifests (GitOps CD)
│   └── dev/                       # Environment-specific ArgoCD apps
├── helm/                          # Helm chart for all 12 microservices
│   ├── templates/                 # Kubernetes manifests (Deployments, Services, HPA)
│   ├── values.yaml                # Base configuration
│   └── values-dev.yaml            # Environment-specific overrides
├── microservices-demo/            # Application source code (Google's demo)
│   └── src/                       # 12 microservices: adservice, cartservice, checkoutservice,
│                                  # currencyservice, emailservice, frontend, loadgenerator,
│                                  # paymentservice, productcatalogservice, recommendationservice,
│                                  # shippingservice, shoppingassistantservice
├── terraform/                     # Infrastructure as Code (AWS)
│   └── environments/
│       ├── global/                # Shared ECR repositories (auto-discovered from src/)
│       └── dev/                   # Dev EKS cluster, VPC, IAM roles
├── docker-compose.yaml            # Local testing (12 services + Redis)
└── README.md                      # This file
```

### Main Folders

| Folder | Purpose | Key Features | Documentation |
|--------|---------|--------------|---------------|
| **`.github/`** | CI/CD automation | Container builds, Terraform automation, security scanning, image promotion | [.github/workflows/README.md](.github/workflows/README.md) |
| **`argocd/`** | GitOps continuous delivery | ArgoCD Application manifests, automated sync, self-heal | [argocd/README.md](argocd/README.md) |
| **`helm/`** | Kubernetes deployment | Helm chart for all services, HPA, per-environment values | [helm/README.md](helm/README.md) |
| **`terraform/`** | Infrastructure provisioning | EKS cluster, VPC, ECR auto-discovery, IAM | [terraform/README.md](terraform/README.md) |
| **`microservices-demo/`** | Application code | 12 polyglot microservices from Google Cloud demo | [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) |
| **`docker-compose.yaml`** | Local development | Run all 12 services locally for testing | See [Local Testing](#local-testing) section |

---

## Architecture & Design Decisions

### Infrastructure Architecture

- **Shared ECR Registry**: Single set of ECR repositories in `terraform/environments/global/` shared across all environments (dev, qa, prod)
  - **Why**: Cost optimization, simplified version management, single source of truth for images
  - **Auto-Discovery**: Terraform scans `microservices-demo/src/*/Dockerfile` to create 12 ECR repositories dynamically
- **Env Auto-Discovery**: Terraform dynamically discovers environments by scanning for catalogs in `terraform/**`
- **Change Discovery**: Terraform and image CI workflows detect only changed enviromnents/microservices
- **Single AWS Account**: All environments (dev, qa, test-qa, prod) deployed in one AWS account
- **Automated Infrastructure Components**: Terraform deploys via Helm:
  - ArgoCD 7.7.12 (GitOps continuous delivery, LoadBalancer exposed)
  - NGINX Ingress Controller 4.10.0 (LoadBalancer with public endpoint, 2 replicas)
  - Metrics Server 3.12.1 (Horizontal Pod Autoscaler support)
  - Prometheus & Grafana 65.0.0 (Monitoring stack, 2h retention, without persistance due to dev auto-mode EKS, LoadBalancer exposed)

### Build & Deployment Strategy

- **Per-Service Builds**: CI pipeline builds ONLY changed microservices, not all services
  - Workflow detects changes per service directory (`microservices-demo/src/<service>/**`)
  - Each service versioned and built independently
  - **To trigger build for all services**: Use bash loop to add `.buildtrigger` to each service directory:
    ```bash
    for dir in microservices-demo/src/*/; do touch "${dir}.buildtrigger"; done
    ```
- **Build Trigger**: Container images built on PR creation (not on merge to main)
  - **Why**: Fast feedback, immutable versioned artifacts, shift-left security scanning
- **Semantic Versioning**: Auto-increment patch version per service independently (e.g., `frontend-1.2.5` > `frontend-1.2.6`)
  - Each microservice maintains its own version number
  - Version tracked in git tags (e.g., `frontend-1.2.6`)
- **Multi-Tag Strategy**: Each build creates multiple tags per service:
  - Immutable: `1.2.6-abc1234` (version + git short SHA)
  - Environment-versioned: `dev-1.2.6`
  - Environment-latest: `dev`
- **Image Promotion**: Manual promotion between environments via workflow_dispatch
  - Uses **Crane** for metadata-only operations (no image pull/push, instant promotion)
  - Supports dynamic environment names (dev, qa, prod, hotfix-202412, etc.)
  - Promotes single service at a time for granular control

### Security & Compliance

- **Security Scanning**: Weekly Trivy scans + scan-on-push to ECR, SARIF upload to GitHub Security
- **IAM Controls**: Boundary policies, least-privilege roles, separate cluster and node roles
- **Encryption**: S3 backend encrypted (AES256), ECR encryption enabled

---

## Pipelines

| Workflow | Trigger | Purpose | Key Actions |
|----------|---------|---------|-------------|
| **ci.yaml** | PR to `main` (changes in `microservices-demo/src/**`) | Build & push container images | Auto-versioning, parallel matrix builds, multi-tagging, git tags |
| **helm-ci.yaml** | PR to `main` (changes in `helm/**`) | Validate Helm charts | Helm lint, template rendering, Kubeconform validation per values file |
| **terraform-ci.yaml** | PR (changes in `terraform/**`) | Validate infrastructure changes | Terraform fmt, validate, plan, post plan as PR comment |
| **terraform-apply.yaml** | Push to `main` (changes in `terraform/**`) | Deploy infrastructure | Auto-apply approved Terraform changes after merge |
| **promote-image.yaml** | Manual (workflow_dispatch) | Promote images across environments | Crane-based metadata copy, dual tagging (versioned + latest) |
| **security-scans.yaml** | Cron (Mon 6AM UTC) + manual | Security vulnerability scanning | Trivy scan all ECR images, SARIF upload to GitHub Security |

**Implementation Details**: See [.github/workflows/README.md](.github/workflows/README.md) for workflow architecture, reusable workflows, and composite actions.

---

## Prerequisites & Requirements

### Required Tools

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| **AWS CLI** | 2.x | AWS resource management, EKS kubeconfig |
| **Terraform** | 1.9.0+ | Infrastructure provisioning |
| **Docker** | 20.x+ | Local testing with docker-compose |
| **kubectl** | 1.34+ | Kubernetes cluster access |
| **Helm** | 3.14+ | Kubernetes package management |
| **Git** | 2.x | Version control |

### AWS Permissions Required

Your AWS user/role needs permissions for:

- **EKS**: Create clusters, node groups, manage add-ons
- **VPC**: Create VPCs, subnets, NAT gateways, route tables, security groups
- **ECR**: Create repositories, push images, configure lifecycle policies
- **IAM**: Create roles, policies, instance profiles (with boundary policies if applicable)
- **S3**: Create buckets, read/write state files
- **CloudFormation**: Read stack status (EKS uses CFN internally)

**IAM Boundary Policy Note**:

- Some AWS environments (AWS Academy, organizational accounts) enforce IAM Permission Boundaries
- If your account has boundary policies, you may need to remove/modify boundary configuration in `terraform/environments/dev/iam.tf`
- For development without boundaries: Comment out or remove `permissions_boundary` lines in IAM role definitions
- See [Step 4b: Configure IAM Boundary Policy](#step-by-step-instructions) in Replication Guide

### GitHub Requirements

- **Repository**: Fork of this project or new repository with this code
- **Branch Protection**: Configure `main` branch protection (require PR reviews, no direct pushes)
- **Secrets & Variables**: See [Required Secrets/Variables](#required-github-secretsvariables) section below

## Required GitHub Secrets/Variables

Configure these in **Settings > Secrets and variables > Actions**:

### Repository Secrets

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key for GitHub Actions | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |

**Security Note**: Use dedicated IAM user for CI/CD with minimal required permissions. Consider using OIDC for keyless authentication in production.

### Repository Variables

| Variable Name | Description | Example |
|--------------|-------------|---------|
| `AWS_REGION` | AWS region for all resources | `eu-west-1` |
| `ECR_REGISTRY_URI` | Full ECR registry URI with project prefix | `123456789012.dkr.ecr.eu-west-1.amazonaws.com/yours-microservices-demo` |
| `TERRAFORM_VERSION` | Terraform version for workflows | `1.9.0` |

**Important**: `ECR_REGISTRY_URI` must include the project name prefix (e.g., `/yours-microservices-demo`), matching `project_name` in `terraform/environments/global/local-vars.tf`.

---

## Full Replication Guide (0 to Working Dev Environment)

This guide walks through setting up the entire project from scratch, including branch protection and PR-based workflow.

### Step-by-Step Instructions

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

**Repository Secrets** (Settings > Secrets and variables > Actions):

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

#### 4b. Configure IAM Boundary Policy (If Applicable)

**Check if your AWS account enforces IAM Permission Boundaries**:

```bash
# List your user's boundary policy
aws iam get-user --user-name $(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2) --query 'User.PermissionsBoundary'
```

**If you have NO boundary policy** (standard AWS account):

- Edit `terraform/environments/dev/iam.tf`
- **Remove or comment out** all `permissions_boundary` lines:

```hcl
# In terraform/environments/dev/iam.tf
resource "aws_iam_role" "eks_cluster_role" {
  name = "${local.project_name}-eks-cluster-role"
  # permissions_boundary = "arn:aws:iam::aws:policy/..." # <- REMOVE THIS LINE
  ...
}

resource "aws_iam_role" "eks_node_role" {
  name = "${local.project_name}-eks-node-role"
  # permissions_boundary = "arn:aws:iam::aws:policy/..." # <- REMOVE THIS LINE
  ...
}
```

**If you have a boundary policy** (AWS Academy, organizational AWS):

- Keep the `permissions_boundary` lines
- Update the ARN to match your account's boundary policy
- Example: `permissions_boundary = "arn:aws:iam::123456789012:policy/YourBoundaryPolicy"`

**Why this matters**: Without proper boundary configuration, EKS cluster and node role creation will fail with IAM permission errors.

#### 5. Deploy Infrastructure

**IMPORTANT**: Deploy in MULTIPLE separate PRs due to "one environment per PR" constraint and Terraform dependency requirements.

##### Step 5a: Deploy Global Resources (ECR Repositories)

Create ECR repositories first - they must exist before building images:

```bash
# Create PR for global environment
git checkout -b terraform/deploy-global
echo "# Deploy ECR" >> terraform/environments/global/ecr.tf
git add terraform/environments/global/
git commit -m "terraform(global): create ECR repositories"
git push origin terraform/deploy-global

# Create PR > Review terraform plan for 12 ECR repos > Merge to main
# Workflow automatically applies > ECR repositories created
```

##### Step 5b: Deploy Dev Environment - Part 1 (EKS Cluster Only)

**CRITICAL**: You MUST comment out resources that depend on EKS cluster data before first deployment to avoid "data source not found" errors.

Files that MUST be commented out:
- **ALL resources in `terraform/environments/dev/helm.tf`** (ArgoCD, NGINX Ingress, Metrics Server, Prometheus/Grafana)
- **ALL resources in `terraform/environments/dev/security-groups.tf`** (they reference EKS cluster data)
- **kubernetes and helm providers in `terraform/environments/dev/providers.tf`** (keep only: aws, random, null)

```bash
# Prepare dev environment configuration
git checkout main
git pull origin main
git checkout -b terraform/deploy-dev-eks

# Comment out the files mentioned above
# In terraform/environments/dev/:
# - Comment out ALL resources in helm.tf
# - Comment out ALL resources in security-groups.tf
# - Comment out kubernetes and helm providers in providers.tf

# Commit the changes
git add terraform/environments/dev/
git commit -m "terraform(dev): prepare for EKS cluster creation (commented dependent resources)"
git push origin terraform/deploy-dev-eks

# Create PR > Review terraform plan > Merge to main
# Workflow automatically applies > EKS cluster + VPC created
# WARNING: This takes ~15-20 minutes (EKS cluster creation)
```

**Why comment out resources?**

- Helm provider needs EKS cluster endpoint (doesn't exist yet)
- Security groups reference EKS cluster data sources (doesn't exist yet)
- Terraform will fail with "data source not found" errors if these are active on first apply

##### Step 5c: Deploy Dev Environment - Part 2 (Helm Components)

After EKS cluster is created, uncomment the resources and deploy Helm components:

```bash
# Wait for Step 5b to complete (check GitHub Actions)
git checkout main
git pull origin main
git checkout -b terraform/deploy-dev-helm

# Uncomment previously commented resources:
# In terraform/environments/dev/:
# - Uncomment ALL resources in helm.tf
# - Uncomment ALL resources in security-groups.tf
# - Uncomment kubernetes and helm providers in providers.tf

# Commit the changes
git add terraform/environments/dev/
git commit -m "terraform(dev): deploy Helm components (ArgoCD, Ingress, Monitoring)"
git push origin terraform/deploy-dev-helm

# Create PR > Review terraform plan > Merge to main
# Workflow automatically applies > ArgoCD, NGINX Ingress, Metrics Server, Prometheus & Grafana deployed
```

**Why Three PRs?**

- **PR 1 (global)**: ECR must exist before image CI can push
- **PR 2 (dev-eks)**: EKS cluster must exist before Helm/Kubernetes providers can work
- **PR 3 (dev-helm)**: Clean separation, allows reviewing infrastructure vs application layer changes
- Terraform workflows enforce one environment change per PR

##### Creating Additional Environments (QA, Prod)

To create a new environment based on dev:

```bash
# 1. Copy dev folder
cp -r terraform/environments/dev terraform/environments/qa

# 2. Create S3 bucket (follow Step 1)
aws s3api create-bucket --bucket <your-name>-kubernetes-tf-state-qa-bucket --region eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1
# + enable versioning and encryption

# 3. Update terraform/environments/qa/backend.tf with new S3 bucket name

# 4. Update terraform/environments/qa/local-vars.tf:
#    project_name = "<your-name>-microservices-demo-qa"
#    tags = { env = "qa", ... }

# 5. Configure/remove IAM boundary policies in terraform/environments/qa/iam.tf (see Step 4b)

# 6. Comment out resources (CRITICAL - same as Step 5b):
#    - ALL resources in terraform/environments/qa/helm.tf
#    - ALL resources in terraform/environments/qa/security-groups.tf
#    - kubernetes/helm providers in terraform/environments/qa/providers.tf

# 7. Create PR for EKS cluster
git checkout -b terraform/deploy-qa-eks
git add terraform/environments/qa/
git commit -m "terraform(qa): create EKS cluster"
git push origin terraform/deploy-qa-eks
# Create PR > Merge > Wait 15-20 min

# 8. Uncomment resources and create PR for Helm components
git checkout -b terraform/deploy-qa-helm
# Uncomment helm.tf, security-groups.tf, providers.tf
git add terraform/environments/qa/
git commit -m "terraform(qa): deploy Helm components"
git push origin terraform/deploy-qa-helm
# Create PR > Merge
```

#### 6. Configure Branch Protection

**In GitHub UI** (Settings > Branches):

1. Add rule for `main` branch
2. Enable: "Require status checks to pass before merging"
3. Enable: "Do not allow bypassing the above settings"

This ensures all changes go through PR review and automated checks (Terraform plan, CI builds, Helm validation).

#### 7. Verify Infrastructure

After infrastructure deployment completes (Step 5), Terraform automatically installs via Helm:

- **ArgoCD** (GitOps CD)
- **NGINX Ingress Controller** (LoadBalancer)
- **Metrics Server** (HPA support)
- **Prometheus & Grafana** (Monitoring)

**Connect to EKS cluster**:

```bash
# Update kubeconfig
aws eks update-kubeconfig --region eu-west-1 --name <project-name>-microservices-demo

# Verify cluster access
kubectl get nodes
kubectl get namespaces

# Check installed components
kubectl get pods -n argocd
kubectl get pods -n ingress-nginx
kubectl get pods -n monitoring
```

**Note**: For accessing ArgoCD UI, Grafana, and other services, see [Step 9: Access Deployed Services](#9-access-deployed-services).

#### 8. First Application Build & Deployment

##### Option A: Build Single Service (Frontend)

```bash
# Make a change to trigger CI build for one service
git checkout -b feature/test-deployment
echo "# Test change" >> microservices-demo/src/frontend/README.md
git add microservices-demo/src/frontend/
git commit -m "feat(frontend): test CI pipeline"
git push origin feature/test-deployment

# Create PR > CI builds ONLY frontend image > Merge to main
# ArgoCD automatically deploys new frontend image to dev environment
```

##### Option B: Build ALL Services (Initial Deployment)

Use this for first deployment to build all 12 microservices at once:

```bash
# Create build trigger files for all services
git checkout -b feature/initial-build
for dir in microservices-demo/src/*/; do
  touch "${dir}.buildtrigger"
done

# Commit and push
git add microservices-demo/src/
git commit -m "ci: trigger initial build for all services"
git push origin feature/initial-build

# Create PR > CI builds ALL 12 services in parallel > Merge to main
# ArgoCD automatically deploys all services to dev environment
```

**Verify Deployment**:

```bash
# Check all pods in dev namespace
kubectl get pods -n dev

# Check services
kubectl get svc -n dev
```

#### 9. Access Deployed Services

After successful deployment, you can access the following services:

##### Frontend (Microservices Application)

```bash
# Get frontend Ingress URL
kubectl get ingress -n dev

# Output example:
# NAME       CLASS   HOSTS   ADDRESS                                      PORTS   AGE
# frontend   nginx   *       a1234567890abcdef.eu-west-1.elb.amazonaws.com   80      5m

# Access in browser using the ADDRESS column
# http://<ADDRESS-from-above>

# Alternative: Port-forward for testing
kubectl port-forward -n dev svc/frontend 8080:8080
# Access: http://localhost:8080
```

##### ArgoCD UI

```bash
# Get ArgoCD LoadBalancer URL
kubectl get svc -n argocd

# Look for argocd-server with type LoadBalancer and EXTERNAL-IP
# Access: http://<EXTERNAL-IP>

# Get initial admin password (base64 decode)
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
echo  # Print newline

# Login credentials:
# Username: admin
# Password: [output from above command]
```

**Deploy your application in ArgoCD**:

After accessing ArgoCD UI, create the Application:

```bash
# Apply ArgoCD Application manifest for dev environment
kubectl apply -f argocd/dev/microservices-demo-dev.yaml -n argocd

# Verify Application is created
kubectl get applications -n argocd

# In ArgoCD UI you should see "microservices-demo-dev" application
# Click on it to see all microservices being synced
```

The ArgoCD Application will automatically sync the Helm chart from `helm/` directory using environment-specific values (`values-dev.yaml`).

##### Grafana (Monitoring Dashboard)

```bash
# Get Grafana LoadBalancer URL
kubectl get svc -n monitoring

# Look for kube-prometheus-stack-grafana with type LoadBalancer and EXTERNAL-IP
# Access: http://<EXTERNAL-IP>

# Login credentials:
# Username: admin
# Password: admin123
# (password is hardcoded in terraform/environments/dev/helm.tf)
```

**Pre-configured Dashboards**:
- Kubernetes Cluster Monitoring
- Pod Metrics
- Node Exporter
- Prometheus Stats

**Note**: LoadBalancer EXTERNAL-IP may take 2-3 minutes to provision after deployment. If you see `<pending>`, wait and retry.

## Local Testing

Test all microservices locally before pushing to AWS using Docker Compose.

### Run All Services

```bash
# Start all 12 microservices + Redis
docker-compose up -d

# View logs
docker-compose logs -f

# Access frontend
open http://localhost:8080

# Stop all services
docker-compose down
```

### Test Individual Services

```bash
# Build specific service
docker-compose build frontend

# Run specific service with dependencies
docker-compose up frontend

# Rebuild and run
docker-compose up --build cartservice
```

### Architecture

The `docker-compose.yaml` includes:

- **12 microservices**: All services from `microservices-demo/src/`
- **Redis**: For cart service state
- **Networking**: All services on `microservices-network` bridge network
- **Port mapping**: Frontend on `8080`, other services on various ports

**Service Dependencies**: Docker Compose respects `depends_on` to start services in correct order (e.g., `frontend` waits for `cartservice`, `productcatalogservice`, etc.).

### Typical Workflow

1. **Local development**: Make changes to service code
2. **Local test**: `docker-compose up --build <service>` to test changes
3. **Create PR**: Push changes and create Pull Request
4. **CI validation**: GitHub Actions builds and pushes images to ECR
5. **Merge**: After approval, merge to main
6. **ArgoCD deployment**: ArgoCD automatically deploys to dev environment

---

## Contribution

I do not expect any contribuions. Feel free to use this project as example of deployment or for educational purposes.

Any new ideas are welcome.
