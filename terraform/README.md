# Terraform Infrastructure

Complete Infrastructure as Code for AWS microservices-demo deployment using Terraform. Splitted in multi environment configuration.

## Architecture

### Shared and Environment-Specific Resources

This project separates infrastructure into two distinct categories:

**Shared Resources (`global/`)**:

- **ECR Repositories**: Single registry for all environments
- **Image Storage**: All environments pull from same repositories

**Environment-Specific Resources (`dev/`, `qa/`, `prod/`)**:

- **VPC & Networking**: Isolated network per environment
- **EKS Cluster**: Separate Kubernetes control plane per environment
- **IAM Roles**: Environment-specific permissions
- **Helm Deployments**: ArgoCD, NGINX, Prometheus/Grafana

### Global ECR

**All environments share a single ECR registry** (`global/ecr.tf`). This is not optional - workflows depend on it:

1. **CI Pipeline** (`ci.yaml`): Pushes images to shared ECR with environment tags (`dev-1.2.3`, `qa-1.2.3`)
2. **Image Promotion** (`promote-image.yaml`): Crane copies tags within same repository (dev → qa)
3. **ArgoCD**: Pulls images from shared ECR using environment-specific tags

**Without global ECR**: Image promotion workflows would fail, requiring full rebuilds per environment.

---

## Directory Structure

```shell
terraform/
└── environments/         # Environment-based organization
    ├── global/           # Shared resources across ALL environments
    │   ├── backend.tf    # S3 state: state/global/terraform.tfstate
    │   ├── providers.tf  # AWS provider configuration
    │   ├── versions.tf   # Terraform & provider version constraints
    │   ├── local-vars.tf # Project name, tags
    │   ├── ecr.tf        # ECR repositories (AUTO-DISCOVERED from src/)
    │   └── outputs.tf    # ECR repository URLs
    │
    └── dev/              # Dev environment (can be copied for qa, prod, etc.)
        ├── backend.tf        # S3 state: state/dev/terraform.tfstate
        ├── providers.tf      # AWS provider + Kubernetes + Helm providers
        ├── versions.tf       # Version constraints
        ├── local-vars.tf     # Environment-specific: VPC name, cluster name, tags
        ├── vpc.tf            # VPC module: subnets, NAT, IGW
        ├── security-groups.tf # Security groups for EKS
        ├── iam.tf            # IAM roles: EKS cluster + node roles
        ├── eks.tf            # EKS module: cluster, node pools, add-ons
        ├── helm.tf           # Helm releases: ArgoCD, NGINX, Prometheus, Metrics Server
        └── outputs.tf        # Cluster endpoint, kubeconfig command
```

### File Responsibility Matrix

| File | Purpose | Shared Across Envs? | Notes |
|------|---------|---------------------|-------|
| **ecr.tf** (global only) | ECR repositories | ✅ **Shared across ALL envs** | Auto-discovered from `src/*/Dockerfile` |
| **backend.tf** | S3 state storage | ❌ Each env has own state file | Prevents state conflicts |
| **providers.tf** | AWS/K8s/Helm provider setup | ❌ Env-specific credentials | K8s provider uses env-specific cluster |
| **vpc.tf** | VPC, subnets, NAT, IGW | ❌ Different CIDR per env | Network isolation |
| **eks.tf** | EKS cluster configuration | ❌ Different config per env | Dev uses auto mode, prod should use managed nodes |
| **iam.tf** | IAM roles for EKS | ❌ Env-specific role names | Dev may use boundary policies, prod should not |
| **helm.tf** | Helm chart deployments | ❌ Env-specific values | ArgoCD, NGINX, monitoring stack |
| **versions.tf** | Version constraints | ✅ Should be identical | Consistency across environments |
| **outputs.tf** | Terraform outputs | ❌ Env-specific values | Endpoints, etc. |

---

## Environments

### `global/` - Shared Resources

Shared resources treated like global environment. To enable multi environment strategy and omit creation of many ENV variables in GitHub I went with monorepo for all images. It eases the interaction and configuration.

Made as container for resources shared across all environments. Required for CI/CD workflows.

**Key Resources**:

1. **ECR Repositories** (Auto-Discovered)
   - Terraform scans `microservices-demo/src/*/Dockerfile`
   - Creates one repository per service: `<project-name>/<service>`
   - Example: `test-microservices-demo/frontend`
   - Adding new service: Add Dockerfile → Terraform auto-creates repository

2. **Lifecycle Policies**
   - Keep last 5 `dev-*` tagged images per service
   - Expire untagged images after 1 day
   - Keep max 10 images total (catch-all)

**Deployment Order**: Deploy `global/` FIRST before any environment. See [Pipeline Integration](#pipeline-integration).

**Example Repository Structure**:

```txt
Full repository name: test-microservices-demo/frontend
Full image URI:       123456789010.dkr.ecr.eu-west-1.amazonaws.com/test-microservices-demo/frontend:dev-1.2.3

Where:
  123456789010.dkr.ecr.eu-west-1.amazonaws.com   = Registry URI
  test-microservices-demo                      = Project name (prefix)
  frontend                                       = Service name
  dev-1.2.3                                      = Environment + version tag
```

### `dev/` - Development Environment

Sample development env with EKS in auto-mode and IAM policy boundaries. Suited for tests, configuration, or small deployment.

**Environment-Specific Characteristics**:

- **EKS Auto Mode**: Enabled for simplified management
  - AWS manages node provisioning, scaling, patching
  - Reduced operational overhead for development
  - **Why auto mode for dev**: Fast setup, minimal maintenance, cost-effective
  - **Any other environment should NOT use auto mode**: Use managed node groups for control

- **IAM Boundary Policies**: May be enabled for AWS Academy/organizational accounts
  - Restricts what IAM roles can be created
  - **Any other environment should NOT use boundary policies**: Standard AWS accounts don't require them
  - See `iam.tf` for configuration

- **Network Design**: Single NAT Gateway for cost optimization
  - **Production should use**: Multi-AZ NAT Gateway for high availability

- **Public API Endpoint**: EKS API publicly accessible for developer convenience
  - **Production should use**: Private endpoint with VPN/bastion access

**Terraform-Managed Helm Deployments**:

All Kubernetes tooling installed automatically via Terraform (`helm.tf`):

- **ArgoCD**: GitOps continuous delivery
- **NGINX Ingress Controller**: LoadBalancer for application access
- **Metrics Server**: Horizontal Pod Autoscaler support
- **Prometheus & Grafana**: Monitoring and observability

### Creating Additional Environments (`qa`, `prod`)

Create new S3 manually. Copy `dev/` directory and adjust configuration.

**Key Differences for any deployment environment**:

| Aspect | Dev | Other |
|--------|-----|------------|
| **EKS Mode** | Auto mode | Managed node groups |
| **IAM Boundaries** | May be enabled (AWS Academy) | Should NOT be enabled |
| **NAT Gateway** | Single (cost optimization) | Multi-AZ (high availability) |
| **API Endpoint** | Public (developer access) | Private (VPN/bastion) |
| **VPC CIDR** | `10.1.0.0/16` | Unique per environment (avoid conflicts) |
| **S3 State Key** | `state/dev/terraform.tfstate` | `state/prod/terraform.tfstate` |

**Steps**:

0. Create new S3 bucket manually
1. Copy `dev/` to new environment: `cp -r dev prod`
2. Update `backend.tf`: Change S3 state key to `state/prod/terraform.tfstate`
3. Update `local-vars.tf`: Change `env` tag to `"prod"`
4. Update `vpc.tf`: Change CIDR to avoid conflicts with other environments
5. Update `eks.tf`: Disable auto mode, configure managed node groups
6. Update `iam.tf`: Remove boundary policies if using standard AWS account
7. Update `helm.tf`: Adjust resource limits, retention policies for production

**Important**: Each environment requires separate PR for deployment. See [Pipeline Integration](#pipeline-integration).

---

## Pipeline Integration

**Terraform workflows auto-discover environments** by scanning `terraform/environments/` directory.

**Critical Workflows**:

- `terraform-ci.yaml`: Detects changed environments, runs plan, posts to PR comments
- `terraform-apply.yaml`: Auto-applies after merge to main
- See [.github/README.md](../.github/README.md) for complete workflow documentation

**Deployment Order Constraint**:

1. **Deploy `global/` FIRST** (separate PR)
   - Creates ECR repositories
   - Required for CI pipeline to push images

2. **Deploy environments** (`dev/`, `qa/`, `prod/`) (separate PRs)
   - One environment per PR (workflow limitation)
   - Uses ECR repositories from global

**Required GitHub Variables**:

All environments share the same variables:
- `ECR_REGISTRY_URI`: Full ECR registry URI with project prefix
- `AWS_REGION`: AWS region for all resources
- Example: `ECR_REGISTRY_URI=123456789010.dkr.ecr.eu-west-1.amazonaws.com/test-microservices-demo`
- Note: Include project name prefix in URI

**Auto-Discovery Mechanism**:

```bash
# Workflow discovers environments
find terraform/environments -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
# Output: global, dev, qa, prod

# Workflow detects changes per environment
git diff --name-only base..HEAD | grep "terraform/environments/"
# Extracts environment name from changed file paths
```

---

## How to Use

To change and deploy infrastructure focus on one env per PR, and work as with any other Terraform HCL format files.  
Change file > create branch > create PR > check workflow output information > merge (auto-apply)

Modules used are publiclly available and have great documentation. One can configure them accordingly to deployment needs.

Same goes for confiuration files (iam, local-vars, outputs, security-groups, prviders, helm, etc.).

### Modules reference

- [EKS module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [VPC](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)

### Initial Setup

See [Main README](../README.md#replication-guide) for complete setup instructions:

- Creating S3 backend
- Configuring GitHub secrets/variables
- Deploying infrastructure via workflows (global first, then dev)

### Creation of New Environment

There are two approaches to make new one.

1. Copy dev
2. Create fully custom suited to ones needs

Here is example flow when copying the dev environment.

- Copy dev folder
- Create S3 bucket manually for Terraform state
- Update `backend.tf` with newly created S3 information
- Comment out all resources in `helm.tf`, `security-groups.tf`, and kubernetes/helm providers with data info from `providers.tf`
- Change/remove boundary policies in `iam.tf`
- Change naming schemes in `local-vars.tf`
- Create PR and merge it after all checks pass (it will take some time to create new EKS)
- Uncomment `helm.tf`, `security-groups.tf`, and kubernetes/helm providers with data info from `providers.tf`
- Create PR and merge it

### Modifying Existing Environment

Deploy via GitHub Workflows using PRs:

```bash
git checkout -b terraform/upgrade-eks
vim terraform/environments/dev/eks.tf # make some change to Trigger CI
git add terraform/
git commit -m "terraform(dev): upgrade EKS configuration"
git push origin terraform/upgrade-eks

# Create PR → Review terraform plan in comments → Merge → Automatic apply
```

### Connecting to EKS Cluster

```bash
aws eks update-kubeconfig \
  --region eu-west-1 \
  --name <project-name>-microservices-demo

kubectl cluster-info
kubectl get nodes
```

---

## Constraints & Limitations

### One Environment Per PR

Workflows support only one environment change per PR. Terraform plan file is saved per env resulting in naming conflict. But it gives clearer review process and guarantee of same apply.

**Solution**: Create separate PRs for each environment.

**Example**:

```bash
# ❌ WRONG: Changing both global and dev in one PR
git add terraform/environments/global/ecr.tf
git add terraform/environments/dev/eks.tf
git commit -m "terraform: update global and dev"

# ✅ CORRECT: Separate PRs
# PR 1: terraform/environments/global/ecr.tf
# PR 2: terraform/environments/dev/eks.tf (after PR 1 merges)
```

See [.github/](../.github) for workflow details.

## Related Documentation

- [Main README](../README.md) - Project overview and setup guide
- [.github/README.md](../.github/README.md) - CI/CD workflows and automation
- [ArgoCD README](../argocd/README.md) - GitOps deployment configuration
- [Terraform AWS Modules](https://registry.terraform.io/namespaces/terraform-aws-modules) - Module documentation
