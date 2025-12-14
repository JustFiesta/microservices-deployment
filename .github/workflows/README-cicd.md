# GitHub Actions CI/CD

Documentation for workflows and automation.

## Contents

```
.github/
├── actions/                                    # Custom composite actions
│   └── terraform-init-validate-plan/           # Reusable Terraform action
│       └── action.yaml
└── workflows/                                  # CI/CD pipelines
    ├── ci.yaml                                 # Container build & push
    ├── terraform-ci.yaml                       # Terraform PR validation
    ├── terraform-apply.yaml                    # Terraform auto-deploy
    ├── promote-image.yaml                      # Image promotion (manual)
    ├── security-scans.yaml                     # Weekly Trivy scans
    ├── reusable_discover-app-services-changes.yaml    # Detect changed services
    ├── reusable_discover-app-services-all.yaml        # Discover all services
    ├── reusable_discover-terraform-envs.yaml          # Discover TF environments
    └── reusable_detect-terraform-changes.yaml         # Detect TF changes
```

## Main Workflows

### 1. Container Image CI (`ci.yaml`)

**Trigger**: Pull requests to `main` with changes in `microservices-demo/src/**`

**Purpose**: Build and push Docker images to ECR with automatic versioning.

**Key Features**:

- **Service Discovery**: Automatically detects which microservices were modified
- **Semantic Versioning**: Auto-increments patch version per service (e.g., `frontend-1.2.5` → `frontend-1.2.6`)
- **Parallel Builds**: Matrix strategy builds all changed services simultaneously
- **Multi-Tag Strategy**: Creates immutable (`1.2.6-abc1234`), environment-specific (`dev-1.2.6`), and latest (`dev`) tags
- **Git Tagging**: Creates annotated git tags on merge to main
- **Build Cache**: Uses GitHub Actions cache for faster rebuilds

**Usage**:

```bash
# Modify a microservice
vim microservices-demo/src/frontend/main.go

# Create PR
git checkout -b feature/new-feature
git add microservices-demo/src/frontend/
git commit -m "feat(frontend): add new feature"
git push origin feature/new-feature

# Workflow automatically:
# - Detects frontend was changed
# - Builds Docker image
# - Pushes to ECR with tags: 1.2.7-abc1234, dev-1.2.7, dev
# - Creates build summary in GitHub Actions UI
```

---

### 2. Terraform CI (`terraform-ci.yaml`)

**Trigger**: Pull requests with changes in `terraform/environments/**` or `terraform/modules/**`

**Purpose**: Validate Terraform changes and generate plan before merge.

**Key Features**:

- **Auto-Format**: Runs `terraform fmt` and auto-commits if needed
- **Multi-Environment**: Detects which environments changed and runs plan for each
- **PR Comments**: Posts Terraform plan as sticky comment in PR
- **Validation**: Ensures Terraform code is valid before merge

**Limitations**:

- More than one environment cannot be chaned in single PR - this will result in error.

    Only one environment can be changed at one time, due to plan file naming. It is also logical to have single PR change per env.

**Usage**:

```bash
# Modify Terraform configuration
vim terraform/environments/dev/eks.tf

# Create PR
git checkout -b terraform/upgrade-eks
git add terraform/
git commit -m "terraform(dev): upgrade EKS to 1.35"
git push origin terraform/upgrade-eks

# Workflow automatically:
# - Formats Terraform code (commits if changes needed)
# - Generates plan for dev environment
# - Posts plan as PR comment for review
```

---

### 3. Terraform Apply (`terraform-apply.yaml`)

**Trigger**: Push to `main` branch with changes in `terraform/environments/**` or `terraform/modules/**`

**Purpose**: Automatically apply approved Terraform changes.

**Key Features**:

- **Auto-Deploy**:
Applies changes immediately after merge
- **Environment Detection**: Only applies to changed environments
- **Audit Trail**: Full logs in GitHub Actions

**Limitations**:

- More than one environment cannot be chaned in single PR - this will result in error.

    Only one environment can be changed at one time, due to plan file naming. It is also logical to have single PR change per env.

**Usage**:

- Automatic after merging Terraform PR
- No manual intervention required
- Review logs in GitHub Actions for apply status

---

### 4. Promote Image (`promote-image.yaml`)

**Trigger**: Manual (workflow_dispatch)

**Purpose**: Promote container images between environments.

**Key Features**:

- **Dynamic Environments**: Supports arbitrary environment names (dev, qa, prod, hotfix-202412, etc.)
- **Fast Promotion**: Uses `crane` for metadata-only operations (no image pull/push)
- **Version Extraction**: Automatically extracts version from source tag
- **Dual Tagging**: Creates both versioned tag (`qa-1.2.6`) and latest tag (`qa`)
- **Validation**: Verifies source image exists before promotion

**Usage**:

```bash
# Find image to promote
aws ecr list-images --repository-name mbocak-microservices-demo/frontend

# Run workflow (GitHub UI):
# Actions → Promote Image → Run workflow
#   Service: frontend
#   Source tag: 1.2.6-abc1234
#   Target env: qa

# Result: Creates tags qa-1.2.6 and qa pointing to the same image
```

**Naming Constraints**:

- `service`: alphanumeric + underscore only (`[a-zA-Z0-9_]+`)
- `target_env`: alphanumeric + dash + underscore (`[a-zA-Z0-9_-]+`)

---

### 5. Security Scans (`security-scans.yaml`)

**Trigger**:

- Scheduled: Every Monday at 6:00 AM UTC
- Manual: workflow_dispatch

**Purpose**: Regular security scanning of all ECR images with Trivy.

**Key Features**:

- **Complete Coverage**: Scans all services × all environments
- **GitHub Security Integration**: Uploads SARIF results to Code Scanning
- **Severity Filtering**: Scans for CRITICAL, HIGH, and MEDIUM vulnerabilities
- **Ignore Unfixed**: Skips vulnerabilities without available fixes

**Usage**:

- Automatic weekly scans
- Manual trigger: Actions → Security Scans → Run workflow
- View results: GitHub → Security tab → Code scanning alerts

---

## Reusable Workflows

These workflows are designed for reuse to avoid code duplication and ensure consistency:

### `reusable_discover-app-services-changes.yaml`

- **Purpose**: Detect which microservices were modified in a PR
- **Output**: JSON array of changed service names (e.g., `["frontend", "cartservice"]`)
- **Used by**: `ci.yaml`

### `reusable_discover-app-services-all.yaml`

- **Purpose**: Find all microservices in the project
- **Output**: JSON array of all service names
- **Used by**: `security-scans.yaml`

### `reusable_discover-terraform-envs.yaml`

- **Purpose**: Discover all Terraform environments
- **Input**: Optional `exclude` parameter (e.g., "global")
- **Output**: JSON array of environment names (e.g., `["dev", "qa", "prod"]`)
- **Used by**: `security-scans.yaml`

### `reusable_detect-terraform-changes.yaml`

- **Purpose**: Detect which Terraform environments were modified
- **Output**: Boolean `has_changes` and array of changed environments
- **Used by**: `terraform-ci.yaml`, `terraform-apply.yaml`

**Why Reusable Workflows?**

- **DRY Principle**: Single source of truth for service/environment discovery
- **Consistency**: Same detection logic across all workflows
- **Maintainability**: Update logic once, applies everywhere
- **Testability**: Can be tested independently

---

## Custom Actions (actions/)

Reusable Terraform workflow steps.

### `terraform-init-validate-plan/`

**Inputs**:

- `working-directory`: Path to Terraform environment directory

**Outputs**:

- `plan-summary`: Short plan summary (e.g., "Plan: 2 to add, 1 to change, 0 to destroy")
- `plan-content`: Full plan output

**Steps**:

1. `terraform init`
2. `terraform validate`
3. `terraform plan -out=tfplan`
4. Parse plan output to structured format

**Why Composite Action?**

- **Reusability**: Used by both `terraform-ci.yaml` and `terraform-apply.yaml`
- **Consistency**: Identical Terraform workflow across CI and apply
- **Simplified Workflows**: Main workflows focus on orchestration, not implementation details

**Usage in Workflow**:

```yaml
- uses: ./.github/actions/terraform-init-validate-plan
  id: plan
  with:
    working-directory: terraform/environments/dev
```

---

## Workflow Architecture

### Why This Structure?

**Separation of Concerns**:

- **Main workflows** (`ci.yaml`, `terraform-*.yaml`): Orchestration and high-level logic
- **Reusable workflows**: Business logic for discovery and detection
- **Composite actions**: Low-level implementation details (Terraform commands)

**Benefits**:

- **Modularity**: Each component has single responsibility
- **Reusability**: Common logic shared across workflows
- **Testability**: Components can be tested independently
- **Maintainability**: Changes to detection logic don't affect main workflows
- **Readability**: Main workflows are concise and focus on what, not how

**Example Flow** (`ci.yaml`):

1. Main workflow triggers on PR
2. Calls `reusable_discover-app-services-changes.yaml` to detect changes
3. Uses output to determine which services to build
4. Builds services in parallel using matrix strategy
5. Each build uses standard Docker actions (not custom)

**Example Flow** (`terraform-ci.yaml`):

1. Main workflow triggers on PR
2. Calls `reusable_detect-terraform-changes.yaml` to find changed environments
3. For each environment, uses composite action `terraform-init-validate-plan`
4. Posts results as PR comment

---

## Required GitHub Secrets/Variables

### Secrets (Settings → Secrets and variables → Actions)

| Name | Description |
|------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS credentials for ECR and Terraform |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key |

### Variables

| Name | Description | Example |
|------|-------------|---------|
| `AWS_REGION` | AWS region | `eu-west-1` |
| `ECR_REGISTRY_URI` | ECR registry URL | `123456789012.dkr.ecr.eu-west-1.amazonaws.com/ecr-name` |
| `TERRAFORM_VERSION` | Terraform version | `1.9.0` |

---

## Workflow Constraints

### Terraform: One Environment Per PR

**Constraint**: `terraform-ci.yaml` and `terraform-apply.yaml` support only one environment change per PR.

**Reason**:

- Plan file naming uses fixed filename `tfplan`
- PR comments use environment name as identifier (conflicts with multiple envs)
- Clearer review process when changes are scoped to single environment

**Solution**: Create separate PRs for each environment change.

```bash
# Good: Separate PRs
git checkout -b terraform/update-dev
# ... modify dev only ...
git push

git checkout -b terraform/update-qa
# ... modify qa only ...
git push

# Bad: Multiple environments in one PR
# ... modify dev and qa together ... ❌
```

### Image Promotion: Naming Constraints

**Service Name**: Alphanumeric + underscore only
- Valid: `frontend`, `cart_service`
- Invalid: `front-end`, `cart.service`

**Environment Name**: Alphanumeric + dash + underscore
- Valid: `qa`, `prod`, `hotfix-202412`
- Invalid: `qa/prod`, `test.env`

**Reason**: ECR tag naming rules and security (injection prevention)

---

## Best Practices

### Commit Messages

Format: `<type>(<scope>): <subject>`

Examples:
```bash
feat(frontend): add shopping cart feature
fix(cartservice): handle empty cart gracefully
terraform(dev): upgrade EKS to 1.35
ci: add security scanning workflow
```

### Branch Naming

| Type | Format | Example |
|------|--------|---------|
| Feature | `feature/<name>` | `feature/shopping-cart` |
| Bugfix | `fix/<name>` | `fix/cart-crash` |
| Terraform | `terraform/<action>-<env>` | `terraform/upgrade-dev` |
| Hotfix | `hotfix/<name>` | `hotfix/critical-bug` |

### Pull Request Workflow

1. Create feature branch
2. Make changes
3. Push and create PR
4. Review automated checks (builds, plans, scans)
5. Address review comments
6. Merge to main
7. Automatic deployment (Terraform) or tagging (container images)

---

## Related Documentation

- [Main README](../README.md) - Project overview
- [Terraform README](../terraform/README.md) - Infrastructure details
- [GitHub Actions Docs](https://docs.github.com/en/actions) - Official documentation
